import Foundation

// MARK: - 跨平台同步载荷

/// 跨平台同步载荷，对应 `docs/sync-protocol.md` 的 `settings.json`。
///
/// 设计原则：
/// - 所有枚举以 `String` 传输，未知值容错降级，避免版本差异导致解码失败
/// - 新增字段必须带默认值
/// - 时间统一 ISO8601 UTC
struct SyncPayload: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var updatedAt: Date
    var updatedBy: String
    var selectedConfig: String
    var core: CoreSection
    var subscriptions: [SubscriptionSection]
    var systemProxy: SystemProxySection
    var ui: UISection
    var ssidRules: [SSIDSection]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case updatedBy
        case selectedConfig
        case core
        case subscriptions
        case systemProxy
        case ui
        case ssidRules
    }

    init(
        schemaVersion: Int = SyncPayload.currentSchemaVersion,
        updatedAt: Date = Date(),
        updatedBy: String,
        selectedConfig: String,
        core: CoreSection,
        subscriptions: [SubscriptionSection],
        systemProxy: SystemProxySection,
        ui: UISection,
        ssidRules: [SSIDSection])
    {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.selectedConfig = selectedConfig
        self.core = core
        self.subscriptions = subscriptions
        self.systemProxy = systemProxy
        self.ui = ui
        self.ssidRules = ssidRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? SyncPayload.currentSchemaVersion
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.updatedBy = try container.decodeIfPresent(String.self, forKey: .updatedBy) ?? ""
        self.selectedConfig = try container.decodeIfPresent(String.self, forKey: .selectedConfig) ?? ""
        self.core = try container.decodeIfPresent(CoreSection.self, forKey: .core)
            ?? CoreSection.fallback
        self.subscriptions = try container.decodeIfPresent([SubscriptionSection].self, forKey: .subscriptions)
            ?? []
        self.systemProxy = try container.decodeIfPresent(SystemProxySection.self, forKey: .systemProxy)
            ?? SystemProxySection.fallback
        self.ui = try container.decodeIfPresent(UISection.self, forKey: .ui) ?? UISection.fallback
        self.ssidRules = try container.decodeIfPresent([SSIDSection].self, forKey: .ssidRules) ?? []
    }
}

// MARK: - 核心设置

struct CoreSection: Codable, Equatable {
    var mode: String
    var allowLan: Bool
    var ipv6: Bool
    var tcpConcurrent: Bool
    var tunEnabled: Bool
    var logLevel: String
    var ports: PortsSection

    static let fallback = CoreSection(
        mode: "rule",
        allowLan: false,
        ipv6: false,
        tcpConcurrent: true,
        tunEnabled: false,
        logLevel: "info",
        ports: .fallback)

    private enum CodingKeys: String, CodingKey {
        case mode
        case allowLan
        case ipv6
        case tcpConcurrent
        case tunEnabled
        case logLevel
        case ports
    }

    init(
        mode: String,
        allowLan: Bool,
        ipv6: Bool,
        tcpConcurrent: Bool,
        tunEnabled: Bool,
        logLevel: String,
        ports: PortsSection)
    {
        self.mode = mode
        self.allowLan = allowLan
        self.ipv6 = ipv6
        self.tcpConcurrent = tcpConcurrent
        self.tunEnabled = tunEnabled
        self.logLevel = logLevel
        self.ports = ports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "rule"
        self.allowLan = try container.decodeIfPresent(Bool.self, forKey: .allowLan) ?? false
        self.ipv6 = try container.decodeIfPresent(Bool.self, forKey: .ipv6) ?? false
        self.tcpConcurrent = try container.decodeIfPresent(Bool.self, forKey: .tcpConcurrent) ?? true
        self.tunEnabled = try container.decodeIfPresent(Bool.self, forKey: .tunEnabled) ?? false
        self.logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel) ?? "info"
        self.ports = try container.decodeIfPresent(PortsSection.self, forKey: .ports) ?? .fallback
    }
}

struct PortsSection: Codable, Equatable {
    var http: Int
    var socks: Int
    var mixed: Int
    var redir: Int
    var tproxy: Int

    static let fallback = PortsSection(http: 0, socks: 0, mixed: 7890, redir: 0, tproxy: 0)

    private enum CodingKeys: String, CodingKey {
        case http
        case socks
        case mixed
        case redir
        case tproxy
    }

    init(http: Int, socks: Int, mixed: Int, redir: Int, tproxy: Int) {
        self.http = http
        self.socks = socks
        self.mixed = mixed
        self.redir = redir
        self.tproxy = tproxy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.http = try container.decodeIfPresent(Int.self, forKey: .http) ?? 0
        self.socks = try container.decodeIfPresent(Int.self, forKey: .socks) ?? 0
        self.mixed = try container.decodeIfPresent(Int.self, forKey: .mixed) ?? 7890
        self.redir = try container.decodeIfPresent(Int.self, forKey: .redir) ?? 0
        self.tproxy = try container.decodeIfPresent(Int.self, forKey: .tproxy) ?? 0
    }
}

// MARK: - 订阅

struct SubscriptionSection: Codable, Equatable {
    var name: String
    var url: String
    var autoUpdate: Bool
    var intervalHours: Int
    var lastUpdateAt: Date?

    private enum CodingKeys: String, CodingKey {
        case name
        case url
        case autoUpdate
        case intervalHours
        case lastUpdateAt
    }

    init(
        name: String,
        url: String,
        autoUpdate: Bool,
        intervalHours: Int,
        lastUpdateAt: Date? = nil)
    {
        self.name = name
        self.url = url
        self.autoUpdate = autoUpdate
        self.intervalHours = max(1, intervalHours)
        self.lastUpdateAt = lastUpdateAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        self.autoUpdate = try container.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? false
        self.intervalHours = max(1, try container.decodeIfPresent(Int.self, forKey: .intervalHours) ?? 6)
        self.lastUpdateAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdateAt)
    }
}

// MARK: - 系统代理

struct SystemProxySection: Codable, Equatable {
    var enabledOnQuit: Bool
    var exceptions: [String]

    static let fallback = SystemProxySection(enabledOnQuit: false, exceptions: [])

    private enum CodingKeys: String, CodingKey {
        case enabledOnQuit
        case exceptions
    }

    init(enabledOnQuit: Bool, exceptions: [String]) {
        self.enabledOnQuit = enabledOnQuit
        self.exceptions = exceptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabledOnQuit = try container.decodeIfPresent(Bool.self, forKey: .enabledOnQuit) ?? false
        self.exceptions = try container.decodeIfPresent([String].self, forKey: .exceptions) ?? []
    }
}

// MARK: - UI

struct UISection: Codable, Equatable {
    var language: String
    var appearance: String

    static let fallback = UISection(language: "zh-Hans", appearance: "system")

    private enum CodingKeys: String, CodingKey {
        case language
        case appearance
    }

    init(language: String, appearance: String) {
        self.language = language
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? "zh-Hans"
        self.appearance = try container.decodeIfPresent(String.self, forKey: .appearance) ?? "system"
    }
}

// MARK: - SSID 规则

struct SSIDSection: Codable, Equatable {
    var ssid: String
    var configFileName: String

    private enum CodingKeys: String, CodingKey {
        case ssid
        case configFileName
    }

    init(ssid: String, configFileName: String) {
        self.ssid = ssid
        self.configFileName = configFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ssid = try container.decodeIfPresent(String.self, forKey: .ssid) ?? ""
        self.configFileName = try container.decodeIfPresent(String.self, forKey: .configFileName) ?? ""
    }
}

// MARK: - 元信息

/// bundle 内单个配置文件的清单项。
///
/// 字段声明严格：清单是解包时的校验依据，缺字段宁可当作「元信息损坏」抛错，
/// 不能默认成空值让校验形同虚设。
struct SyncedConfigEntry: Codable, Equatable {
    var name: String
    var sha256: String
    var bytes: Int

    private enum CodingKeys: String, CodingKey {
        case name
        case sha256
        case bytes
    }

    init(name: String, sha256: String, bytes: Int) {
        self.name = name
        self.sha256 = sha256
        self.bytes = bytes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.sha256 = try container.decode(String.self, forKey: .sha256)
        self.bytes = try container.decode(Int.self, forKey: .bytes)
    }
}

/// 远端 `meta.json`：下载缓存探测 + 冲突判定 + bundle 完整性校验。
///
/// 现在它是 `bundle.zip` 之外唯一的小文件（~500B），同步时先取它决定要不要下全量。
/// 它不再充当「伪事务的提交标记」——zip 本身就原子。
struct SyncMetadata: Codable, Equatable {
    var schemaVersion: Int
    var deviceName: String
    var updatedAt: Date
    var appVersion: String
    var platform: String
    /// `bundle.zip` 的 sha256。为空表示旧的扁平布局（≤0.3.6）
    var bundleSha256: String
    var bundleBytes: Int
    /// bundle 内的配置清单，按名字排序
    var configs: [SyncedConfigEntry]
    var settingsSha256: String
    /// 旧布局里的配置哈希，仅用于识别/读取旧远端
    var legacyConfigSha256: String

    /// 旧布局：配置是 `config/<name>.yaml` 扁平文件，没有 bundle
    var isLegacyLayout: Bool {
        self.bundleSha256.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case deviceName
        case updatedAt
        case appVersion
        case platform
        case bundleSha256
        case bundleBytes
        case configs
        case settingsSha256
        case legacyConfigSha256 = "configSha256"
    }

    init(
        schemaVersion: Int = SyncPayload.currentSchemaVersion,
        deviceName: String,
        updatedAt: Date,
        appVersion: String,
        platform: String,
        bundleSha256: String,
        bundleBytes: Int,
        configs: [SyncedConfigEntry],
        settingsSha256: String,
        legacyConfigSha256: String = "")
    {
        self.schemaVersion = schemaVersion
        self.deviceName = deviceName
        self.updatedAt = updatedAt
        self.appVersion = appVersion
        self.platform = platform
        self.bundleSha256 = bundleSha256
        self.bundleBytes = bundleBytes
        self.configs = configs
        self.settingsSha256 = settingsSha256
        self.legacyConfigSha256 = legacyConfigSha256
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? SyncPayload.currentSchemaVersion
        self.deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? ""
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? ""
        self.bundleSha256 = try container.decodeIfPresent(String.self, forKey: .bundleSha256) ?? ""
        self.bundleBytes = try container.decodeIfPresent(Int.self, forKey: .bundleBytes) ?? 0
        self.configs = try container.decodeIfPresent([SyncedConfigEntry].self, forKey: .configs) ?? []
        self.settingsSha256 = try container.decodeIfPresent(String.self, forKey: .settingsSha256) ?? ""
        self.legacyConfigSha256 = try container.decodeIfPresent(
            String.self,
            forKey: .legacyConfigSha256) ?? ""
    }
}

// MARK: - JSON 编解码

extension JSONEncoder {
    /// 同步协议统一使用的编码器：ISO8601 时间 + 键排序 + 不转义中文。
    static var sync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

extension JSONDecoder {
    static var sync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
