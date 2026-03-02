import Foundation

enum RuntimeVisualStatus {
    case stopped
    case starting
    case runningHealthy
    case runningDegraded
    case failed
}

enum StartTrigger {
    case manual
    case auto
}

enum CoreActionState {
    case idle
    case starting
    case stopping
    case restarting
}

enum ConfigLogLevel: String, CaseIterable {
    case silent
    case error
    case warning
    case info
    case debug
}

enum ConfigPatchValue: Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)
    indirect case object([String: ConfigPatchValue])

    var jsonValue: JSONValue {
        switch self {
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .int(value)
        case let .string(value):
            return .string(value)
        case let .object(value):
            return .object(value.mapValues(\.jsonValue))
        }
    }
}

enum StatusBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly = "icon_only"
    case iconAndSpeed = "icon_and_speed"
    case speedOnly = "speed_only"

    var id: String { rawValue }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }
}

enum MenuPanelTabHint: Equatable {
    case proxy
    case rules
    case activity
    case logs
    case system
}

struct DataAcquisitionPolicy: Equatable {
    let enableTrafficStream: Bool
    let enableMemoryStream: Bool
    let enableConnectionsStream: Bool
    let connectionsIntervalMilliseconds: Int?
    let enableLogsStream: Bool
    let mediumFrequencyIntervalNanoseconds: UInt64
    let lowFrequencyIntervalNanoseconds: UInt64
}

enum ProviderRefreshTrigger {
    case start
    case restart
    case configSwitch
}

enum ProviderRefreshPhase {
    case idle
    case updating
    case succeeded
    case failed
    case cancelled
}

struct ProviderRefreshStatus {
    let phase: ProviderRefreshPhase
    let trigger: ProviderRefreshTrigger?
    let progressDone: Int
    let progressTotal: Int
    let message: String?
    let updatedAt: Date?

    static let idle = ProviderRefreshStatus(
        phase: .idle,
        trigger: nil,
        progressDone: 0,
        progressTotal: 0,
        message: nil,
        updatedAt: nil
    )
}

struct ProviderNodeKey: Hashable {
    let provider: String
    let node: String
}

struct MenuBarSpeedLines: Equatable {
    let up: String
    let down: String

    static let zero = MenuBarSpeedLines(up: "↑0B", down: "↓0B")
}

struct MenuBarDisplay: Equatable {
    let mode: StatusBarDisplayMode
    let symbolName: String?
    let speedLines: MenuBarSpeedLines?
}

struct EditableSettingsSnapshot: Equatable, Codable {
    let allowLan: Bool
    let ipv6: Bool
    let unifiedDelay: Bool
    let tunEnabled: Bool
    let logLevel: String
    let port: String
    let socksPort: String
    let mixedPort: String
    let redirPort: String
    let tproxyPort: String

    private enum CodingKeys: String, CodingKey {
        case allowLan
        case ipv6
        case unifiedDelay
        case tunEnabled
        case logLevel
        case port
        case socksPort
        case mixedPort
        case redirPort
        case tproxyPort
    }

    init(config: ConfigSnapshot) {
        allowLan = config.allowLan ?? false
        ipv6 = config.ipv6 ?? false
        unifiedDelay = config.unifiedDelay ?? false
        tunEnabled = config.tunEnabled ?? false
        logLevel = ConfigLogLevel(rawValue: config.logLevel ?? "")?.rawValue ?? ConfigLogLevel.info.rawValue
        port = config.port.map(String.init) ?? ""
        socksPort = config.socksPort.map(String.init) ?? ""
        mixedPort = config.mixedPort.map(String.init) ?? ""
        redirPort = config.redirPort.map(String.init) ?? ""
        tproxyPort = config.tproxyPort.map(String.init) ?? ""
    }

    init(
        allowLan: Bool,
        ipv6: Bool,
        unifiedDelay: Bool,
        tunEnabled: Bool,
        logLevel: String,
        port: String,
        socksPort: String,
        mixedPort: String,
        redirPort: String,
        tproxyPort: String
    ) {
        self.allowLan = allowLan
        self.ipv6 = ipv6
        self.unifiedDelay = unifiedDelay
        self.tunEnabled = tunEnabled
        self.logLevel = logLevel
        self.port = port
        self.socksPort = socksPort
        self.mixedPort = mixedPort
        self.redirPort = redirPort
        self.tproxyPort = tproxyPort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowLan = try container.decode(Bool.self, forKey: .allowLan)
        ipv6 = try container.decode(Bool.self, forKey: .ipv6)
        unifiedDelay = try container.decode(Bool.self, forKey: .unifiedDelay)
        tunEnabled = try container.decodeIfPresent(Bool.self, forKey: .tunEnabled) ?? false
        logLevel = try container.decode(String.self, forKey: .logLevel)
        port = try container.decode(String.self, forKey: .port)
        socksPort = try container.decode(String.self, forKey: .socksPort)
        mixedPort = try container.decode(String.self, forKey: .mixedPort)
        redirPort = try container.decode(String.self, forKey: .redirPort)
        tproxyPort = try container.decode(String.self, forKey: .tproxyPort)
    }
}

extension EditableSettingsSnapshot {
    func withTunEnabled(_ enabled: Bool) -> EditableSettingsSnapshot {
        EditableSettingsSnapshot(
            allowLan: allowLan,
            ipv6: ipv6,
            unifiedDelay: unifiedDelay,
            tunEnabled: enabled,
            logLevel: logLevel,
            port: port,
            socksPort: socksPort,
            mixedPort: mixedPort,
            redirPort: redirPort,
            tproxyPort: tproxyPort
        )
    }
}

struct SystemProxyPorts: Equatable, Sendable {
    let httpPort: Int?
    let httpsPort: Int?
    let socksPort: Int?

    static let disabled = SystemProxyPorts(httpPort: nil, httpsPort: nil, socksPort: nil)

    var hasEnabledPort: Bool {
        httpPort != nil || httpsPort != nil || socksPort != nil
    }

    var primaryPort: Int? {
        httpPort ?? httpsPort ?? socksPort
    }
}
