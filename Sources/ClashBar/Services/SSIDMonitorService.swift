import AppKit
import CoreLocation
import CoreWLAN
import Foundation

enum SSIDMonitorAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case servicesDisabled
}

struct SSIDMonitorSnapshot: Equatable {
    let currentSSID: String?
    let authorizationStatus: SSIDMonitorAuthorizationStatus
}

enum SSIDMonitorServiceError: LocalizedError {
    case missingLocationUsageDescription
    case developmentBundleBootstrapFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingLocationUsageDescription:
            "Missing NSLocationWhenInUseUsageDescription in the app bundle."
        case let .developmentBundleBootstrapFailed(reason):
            "Failed to prepare a development app bundle for Wi-Fi permission: \(reason)"
        }
    }
}

final class SSIDMonitorService: NSObject {
    typealias SnapshotHandler = @Sendable (SSIDMonitorSnapshot) -> Void
    typealias ErrorHandler = @Sendable (Error) -> Void

    private static let monitoredEventTypes: [CWEventType] = [.ssidDidChange, .linkDidChange]
    private static let locationUsageDescriptionKey = "NSLocationWhenInUseUsageDescription"
    private static let developmentBundleName = "ClashBar Dev.app"
    private static let developmentLocationUsageDescription =
        "ClashBar uses your current Wi-Fi name to switch proxy config profiles automatically."

    private var wifiClient: CWWiFiClient
    private let locationManager: CLLocationManager

    private var snapshotHandler: SnapshotHandler?
    private var errorHandler: ErrorHandler?
    private var isStarted = false
    private var monitoredEventTypesStarted: Set<CWEventType> = []

    init(
        wifiClient: CWWiFiClient = CWWiFiClient(),
        locationManager: CLLocationManager = CLLocationManager())
    {
        self.wifiClient = wifiClient
        self.locationManager = locationManager
        super.init()
    }

    deinit {
        self.stop()
    }

    func start(snapshotHandler: @escaping SnapshotHandler, errorHandler: @escaping ErrorHandler) {
        self.snapshotHandler = snapshotHandler
        self.errorHandler = errorHandler
        guard !self.isStarted else {
            self.emitCurrentSnapshot()
            return
        }

        self.isStarted = true
        self.locationManager.delegate = self
        self.wifiClient.delegate = self
        self.startMonitoringEventsIfNeeded()
        self.emitCurrentSnapshot()
    }

    func stop() {
        guard self.isStarted else { return }
        self.isStarted = false
        self.monitoredEventTypesStarted.removeAll()

        try? self.wifiClient.stopMonitoringAllEvents()
        self.wifiClient.delegate = nil
        self.locationManager.delegate = nil
        self.snapshotHandler = nil
        self.errorHandler = nil
    }

    func refresh() {
        self.startMonitoringEventsIfNeeded()
        self.emitCurrentSnapshot()
    }

    func requestAuthorizationIfNeeded() {
        self.startMonitoringEventsIfNeeded()

        guard CLLocationManager.locationServicesEnabled() else {
            self.emitCurrentSnapshot()
            return
        }

        if self.locationManager.authorizationStatus == .notDetermined {
            guard self.hasLocationUsageDescription() else {
                if self.bootstrapDevelopmentAppBundleIfNeeded() {
                    return
                }
                self.errorHandler?(SSIDMonitorServiceError.missingLocationUsageDescription)
                self.emitCurrentSnapshot()
                return
            }
            self.locationManager.requestWhenInUseAuthorization()
            return
        }

        self.emitCurrentSnapshot()
    }

    private func startMonitoringEventsIfNeeded() {
        for eventType in Self.monitoredEventTypes where !self.monitoredEventTypesStarted.contains(eventType) {
            do {
                try self.wifiClient.startMonitoringEvent(with: eventType)
                self.monitoredEventTypesStarted.insert(eventType)
            } catch {
                self.errorHandler?(error)
            }
        }
    }

    private func emitCurrentSnapshot() {
        self.snapshotHandler?(self.makeSnapshot())
    }

    private func makeSnapshot() -> SSIDMonitorSnapshot {
        let authorizationStatus = self.currentAuthorizationStatus()
        let currentSSID: String? = if authorizationStatus == .authorized {
            self.currentSSID()
        } else {
            nil
        }

        return SSIDMonitorSnapshot(
            currentSSID: currentSSID?.trimmedNonEmpty,
            authorizationStatus: authorizationStatus)
    }

    private func currentAuthorizationStatus() -> SSIDMonitorAuthorizationStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .servicesDisabled
        }

        return switch self.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }

    private func currentSSID() -> String? {
        if let ssid = self.wifiClient.interface()?.ssid()?.trimmedNonEmpty {
            return ssid
        }

        for name in self.wifiClient.interfaceNames() ?? [] {
            if let ssid = self.wifiClient.interface(withName: name)?.ssid()?.trimmedNonEmpty {
                return ssid
            }
        }

        return nil
    }

    private func hasLocationUsageDescription() -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: Self.locationUsageDescriptionKey) as? String else {
            return false
        }

        return value.trimmedNonEmpty != nil
    }

    private func bootstrapDevelopmentAppBundleIfNeeded() -> Bool {
        guard Bundle.main.bundleURL.pathExtension != "app" else {
            return false
        }

        do {
            let appURL = try self.prepareDevelopmentAppBundle()
            guard NSWorkspace.shared.open(appURL) else {
                throw SSIDMonitorServiceError.developmentBundleBootstrapFailed(
                    "Launch Services could not open \(appURL.lastPathComponent).")
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return true
        } catch {
            self.errorHandler?(error)
            self.emitCurrentSnapshot()
            return true
        }
    }

    private func prepareDevelopmentAppBundle() throws -> URL {
        let fileManager = FileManager.default
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let buildDirectoryURL = executableURL.deletingLastPathComponent()
        let appURL = buildDirectoryURL.appendingPathComponent(Self.developmentBundleName, isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let bundledExecutableURL = macOSURL.appendingPathComponent(executableURL.lastPathComponent, isDirectory: false)
        let resourceBundleURL = Bundle.module.bundleURL
        let bundledResourceURL = resourcesURL.appendingPathComponent(
            resourceBundleURL.lastPathComponent,
            isDirectory: true)

        if fileManager.fileExists(atPath: appURL.path) {
            try fileManager.removeItem(at: appURL)
        }

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: bundledExecutableURL, withDestinationURL: executableURL)
        if fileManager.fileExists(atPath: resourceBundleURL.path) {
            try fileManager.createSymbolicLink(at: bundledResourceURL, withDestinationURL: resourceBundleURL)
        }

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
        <key>CFBundleExecutable</key><string>\(executableURL.lastPathComponent)</string>
        <key>CFBundleIdentifier</key><string>com.clashbar.dev</string>
        <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
        <key>CFBundleName</key><string>ClashBar</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>CFBundleShortVersionString</key><string>1.0</string>
        <key>CFBundleVersion</key><string>1</string>
        <key>LSUIElement</key><true/>
        <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
        <key>NSLocationWhenInUseUsageDescription</key><string>\(Self.developmentLocationUsageDescription)</string>
        </dict></plist>
        """
        try infoPlist.write(
            to: contentsURL.appendingPathComponent("Info.plist", isDirectory: false),
            atomically: true,
            encoding: .utf8)
        return appURL
    }
}

extension SSIDMonitorService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.emitCurrentSnapshot()
    }
}

extension SSIDMonitorService: CWEventDelegate {
    func clientConnectionInterrupted() {
        self.emitCurrentSnapshot()
    }

    func clientConnectionInvalidated() {
        self.wifiClient.delegate = nil
        self.monitoredEventTypesStarted.removeAll()
        self.wifiClient = CWWiFiClient()
        self.wifiClient.delegate = self
        self.startMonitoringEventsIfNeeded()
        self.emitCurrentSnapshot()
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        self.emitCurrentSnapshot()
    }

    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        self.emitCurrentSnapshot()
    }
}
