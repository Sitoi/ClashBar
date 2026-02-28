import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var statusText: String = "Stopped" { didSet { refreshMenuBarDisplaySnapshotIfNeeded() } }
    @Published var version: String = "-"
    @Published var controller: String = "127.0.0.1:9090"
    @Published var controllerUIURL: String = "http://127.0.0.1:9090/ui"
    @Published var controllerSecret: String?

    @Published var traffic = TrafficSnapshot(up: 0, down: 0) { didSet { refreshMenuBarDisplaySnapshotIfNeeded() } }
    @Published var memory = MemorySnapshot(inuse: 0)
    @Published var displayUpTotal: Int64 = 0
    @Published var displayDownTotal: Int64 = 0
    @Published var trafficHistoryUp: [Int64] = []
    @Published var trafficHistoryDown: [Int64] = []

    @Published var connectionsCount: Int = 0
    @Published var connections: [ConnectionSummary] = []

    @Published var currentMode: CoreMode = .rule
    @Published var logLevel: String = "info"
    @Published var port: Int?
    @Published var socksPort: Int?
    @Published var redirPort: Int?
    @Published var tproxyPort: Int?
    @Published var mixedPort: Int = 7890

    @Published var mihomoBinaryPath: String = "-"
    @Published var selectedConfigName: String = "-"
    @Published var configDirectoryPath: String = "-"
    @Published var availableConfigFileNames: [String] = []

    @Published var proxyGroups: [ProxyGroup] = []
    @Published var groupLatencyLoading: Set<String> = []
    @Published var groupLatencies: [String: [String: Int]] = [:]
    @Published var proxyHistoryLatestDelay: [String: Int] = [:]

    @Published var providerProxyCount: Int = 0
    @Published var providerRuleCount: Int = 0
    @Published var rulesCount: Int = 0
    @Published var proxyProvidersDetail: [String: ProviderDetail] = [:]
    @Published var expandedProxyProviders: Set<String> = []
    @Published var providerNodeLatencies: [String: [String: Int]] = [:]
    @Published var providerNodeTesting: Set<ProviderNodeKey> = []
    @Published var providerBatchTesting: Set<String> = []
    @Published var providerUpdating: Set<String> = []
    @Published var ruleProviders: [String: ProviderDetail] = [:]
    @Published var ruleItems: [RuleItem] = []
    @Published var isRuleProvidersRefreshing: Bool = false

    @Published var isSystemProxyEnabled: Bool = false
    @Published var isProxySyncing: Bool = false

    @Published var apiStatus: APIHealth = .unknown { didSet { refreshMenuBarDisplaySnapshotIfNeeded() } }
    @Published var errorLogs: [AppErrorLogEntry] = []
    @Published var startupErrorMessage: String?
    @Published var coreActionState: CoreActionState = .idle
    @Published var providerRefreshStatus: ProviderRefreshStatus = .idle
    @Published var uiLanguage: AppLanguage = .zhHans
    @Published var isPanelPresented: Bool = false
    @Published var activeMenuTab: MenuPanelTabHint = .proxy
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginErrorMessage: String?
    @Published private(set) var menuBarDisplaySnapshot = MenuBarDisplay(
        mode: .iconOnly,
        symbolName: "bolt.slash.circle",
        speedLines: nil
    )

    @Published var settingsAllowLan: Bool = false { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsIPv6: Bool = false { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsUnifiedDelay: Bool = false { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsLogLevel: String = ConfigLogLevel.info.rawValue { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsPort: String = "0" { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsSocksPort: String = "0" { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsMixedPort: String = "7890" { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsRedirPort: String = "0" { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsTProxyPort: String = "0" { didSet { persistEditableSettingsSnapshot() } }
    @Published var settingsSyncingKey: String?
    @Published var settingsErrorMessage: String?
    @Published var settingsSavedMessage: String?
    var lastSyncedEditableSettings: EditableSettingsSnapshot?
    var preserveLocalSettingsOnNextSync = false
    var pendingConfigSwitchOverlaySettings: EditableSettingsSnapshot?
    var pendingAppLaunchOverlaySettings: EditableSettingsSnapshot?
    var suppressSettingsPersistence = false

    var runtimeVisualStatus: RuntimeVisualStatus {
        let normalized = statusText.lowercased()
        if normalized == "starting" { return .starting }
        if normalized == "failed" { return .failed }

        let running = processManager.isRunning || normalized == "running"
        if running {
            switch apiStatus {
            case .healthy:
                return .runningHealthy
            case .failed:
                return .failed
            case .degraded, .unknown:
                return .runningDegraded
            }
        }
        return .stopped
    }

    var runtimeStatusText: String {
        switch runtimeVisualStatus {
        case .starting: return tr("app.runtime.starting")
        case .runningHealthy, .runningDegraded: return tr("app.runtime.running")
        case .failed: return tr("app.runtime.failed")
        case .stopped: return tr("app.runtime.stopped")
        }
    }

    // DRY: unify "running" checks across AppState and extensions.
    var isRuntimeRunning: Bool {
        processManager.isRunning || statusText.caseInsensitiveCompare("running") == .orderedSame
    }

    var menuBarSymbolName: String {
        switch runtimeVisualStatus {
        case .runningHealthy:
            return "bolt.horizontal.circle.fill"
        case .runningDegraded:
            return "bolt.horizontal.circle"
        case .starting:
            return "clock.arrow.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .stopped:
            return "bolt.slash.circle"
        }
    }

    var statusBarDisplayMode: StatusBarDisplayMode {
        get { StatusBarDisplayMode(rawValue: statusBarDisplayModeRaw) ?? .iconOnly }
        set {
            guard statusBarDisplayModeRaw != newValue.rawValue else { return }
            statusBarDisplayModeRaw = newValue.rawValue
            refreshMenuBarDisplaySnapshotIfNeeded()
        }
    }

    var menuBarSpeedLines: MenuBarSpeedLines {
        guard isRuntimeRunning else { return .zero }

        let up = compactMenuBarRate(max(0, traffic.up))
        let down = compactMenuBarRate(max(0, traffic.down))
        return MenuBarSpeedLines(up: "↑\(up)", down: "↓\(down)")
    }

    var menuBarDisplay: MenuBarDisplay {
        menuBarDisplaySnapshot
    }

    private var computedMenuBarDisplay: MenuBarDisplay {
        switch statusBarDisplayMode {
        case .iconOnly:
            return MenuBarDisplay(mode: .iconOnly, symbolName: menuBarSymbolName, speedLines: nil)
        case .iconAndSpeed:
            return MenuBarDisplay(mode: .iconAndSpeed, symbolName: menuBarSymbolName, speedLines: menuBarSpeedLines)
        case .speedOnly:
            return MenuBarDisplay(mode: .speedOnly, symbolName: nil, speedLines: menuBarSpeedLines)
        }
    }

    func compactMenuBarRate(_ bytesPerSecond: Int64) -> String {
        var value = Double(max(0, bytesPerSecond))
        let units = ["B", "K", "M", "G", "T"]
        var unitIndex = 0

        while value >= 1000, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        let integer = min(999, Int(value))
        return "\(integer)\(units[unitIndex])"
    }

    func refreshMenuBarDisplaySnapshotIfNeeded() {
        let next = computedMenuBarDisplay
        guard next != menuBarDisplaySnapshot else { return }
        menuBarDisplaySnapshot = next
    }

    var isModeSwitchEnabled: Bool {
        processManager.isRunning && apiStatus == .healthy
    }

    var autoStartCoreEnabled: Bool {
        get { autoStartCore }
        set { autoStartCore = newValue }
    }

    var isCoreActionProcessing: Bool {
        coreActionState != .idle
    }

    var primaryCoreActionLabel: String {
        if isCoreActionProcessing { return tr("app.primary.processing") }
        return isRuntimeRunning ? tr("app.primary.restart") : tr("app.primary.start")
    }

    var primaryCoreActionIconName: String {
        if isCoreActionProcessing { return "hourglass" }
        return isRuntimeRunning ? "arrow.clockwise" : "play.fill"
    }

    var isPrimaryCoreActionEnabled: Bool {
        !isCoreActionProcessing
    }

    let processManager: any MihomoControlling
    let configManager: ConfigDirectoryManager
    let workingDirectoryManager: WorkingDirectoryManager
    let systemProxyService: SystemProxyService
    let configImportService: ConfigImportService
    let appLaunchService: AppLaunchService
    var apiClient: MihomoAPIClient?
    var modeSwitchTransportOverride: MihomoAPITransporting?
    var settingsPatchTransportOverride: MihomoAPITransporting?

    var mediumFrequencyTask: Task<Void, Never>?
    var lowFrequencyTask: Task<Void, Never>?
    var streamReceiveTasks: [StreamKind: Task<Void, Never>] = [:]
    var streamWebSocketTasks: [StreamKind: URLSessionWebSocketTask] = [:]
    var streamReconnectAttempts: [String: Int] = [:]
    var streamLastDisconnectLogAt: [String: Date] = [:]
    var streamLastDisconnectLogMessage: [String: String] = [:]
    var proxyPortsAutoSaveTask: Task<Void, Never>?
    var settingsFeedbackClearTask: Task<Void, Never>?
    var providerRefreshTask: Task<Void, Never>?
    var providerRefreshGeneration: Int = 0
    var lastTrafficSampleAt: Date?
    var modeSwitchInFlight = false

    let defaults = UserDefaults.standard
    @AppStorage("clashbar.auto.start.core") private var autoStartCore: Bool = false
    @AppStorage("clashbar.statusbar.display.mode") private var statusBarDisplayModeRaw: String = StatusBarDisplayMode.iconOnly.rawValue
    let selectedConfigKey = "clashbar.config.selected.filename"
    let legacySelectedConfigKey = "clashbar.config.selected"
    let remoteConfigSourcesKey = "clashbar.config.remote.sources.v1"
    let lastSuccessfulConfigPathKey = "clashbar.last.success.config.path"
    let editableSettingsSnapshotKey = "clashbar.settings.editable.snapshot.v1"
    let uiLanguageKey = "clashbar.ui.language"
    let maxLogEntries = 200
    let hiddenPanelMaxInMemoryLogEntries = 20
    let maxRetainedConnections = 300
    let historyMaxPoints = 60
    let foregroundMediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    let backgroundMediumFrequencyIntervalNanoseconds: UInt64 = 12_000_000_000
    let foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: UInt64 = 20_000_000_000
    let foregroundLowFrequencyOtherTabsIntervalNanoseconds: UInt64 = 45_000_000_000
    let backgroundLowFrequencyIntervalNanoseconds: UInt64 = 120_000_000_000
    let streamDisconnectLogThrottleInterval: TimeInterval = 2
    let streamReconnectBaseDelayNanoseconds: UInt64 = 1_000_000_000
    let streamReconnectMaxDelayNanoseconds: UInt64 = 8_000_000_000
    // DRY: shared defaults for latency/provider healthcheck endpoints.
    let defaultHealthcheckURL = "https://www.gstatic.com/generate_204"
    let defaultHealthcheckTimeoutMilliseconds = 5000
    var mediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    var lowFrequencyIntervalNanoseconds: UInt64 = 20_000_000_000
    var currentConnectionsStreamIntervalMilliseconds: Int?
    var appLogFileURL: URL?
    var appLogStore: AppLogStore?
    var didAttemptAutoStart = false
    var didCheckSystemProxyConsistencyOnLaunch = false
    var remoteConfigSources: [String: String] = [:]
    var externalControllerWarningKeys: Set<String> = []
    let streamJSONDecoder = JSONDecoder()

    init(
        processManager: (any MihomoControlling)? = nil,
        configManager: ConfigDirectoryManager? = nil,
        workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager(),
        systemProxyService: SystemProxyService = SystemProxyService(),
        configImportService: ConfigImportService = ConfigImportService(),
        appLaunchService: AppLaunchService = AppLaunchService(),
        appLogStore: AppLogStore? = nil,
        startBackgroundRefresh: Bool = true
    ) {
        self.processManager = processManager ?? MihomoProcessManager()
        self.workingDirectoryManager = workingDirectoryManager
        self.systemProxyService = systemProxyService
        self.configImportService = configImportService
        self.appLaunchService = appLaunchService
        self.appLogStore = appLogStore
        self.configManager = configManager ?? ConfigDirectoryManager(workingDirectoryManager: workingDirectoryManager)
        uiLanguage = loadPersistedUILanguage()
        refreshLaunchAtLoginStatus()

        if let managedProcess = self.processManager as? MihomoProcessManager {
            mihomoBinaryPath = managedProcess.detectedBinaryPath ?? "-"
            managedProcess.onLog = { [weak self] line in
                Task { @MainActor in
                    self?.appendLog(level: "info", message: line)
                }
            }
            managedProcess.onTermination = { [weak self] code in
                Task { @MainActor in
                    self?.statusText = "Failed"
                    self?.apiStatus = .failed
                    self?.resetTrafficPresentation()
                    self?.appendLog(level: "error", message: self?.tr("log.process.terminated", code) ?? "")
                    self?.cancelPolling()
                }
            }
        } else {
            mihomoBinaryPath = "-"
        }
        do {
            try self.workingDirectoryManager.bootstrapDirectories()
            appLogFileURL = self.workingDirectoryManager.logsDirectoryURL.appendingPathComponent("clashbar.log", isDirectory: false)
            if let appLogFileURL, self.appLogStore == nil {
                self.appLogStore = AppLogStore(logFileURL: appLogFileURL)
            }
            ensureLogFileExists()
            seedBundledConfigIfNeeded()
        } catch {
            appendLog(level: "error", message: tr("log.working_dir_init_failed", error.localizedDescription))
        }
        restoreSavedConfigDirectory()
        restoreLastSuccessfulConfigIfAvailable()
        remoteConfigSources = loadPersistedRemoteConfigSources()
        pruneRemoteConfigSourcesIfNeeded()
        controllerUIURL = makeControllerUIURL(controller)
        if let persisted = loadPersistedEditableSettingsSnapshot() {
            applyEditableSettingsSnapshotToUI(persisted)
            preserveLocalSettingsOnNextSync = true
            pendingAppLaunchOverlaySettings = persisted
        }

        if startBackgroundRefresh {
            Task {
                await refreshFromAPI(includeSlowCalls: true)
                await applyPendingAppLaunchSettingsOverlayIfNeeded()
                await refreshSystemProxyStatus()
                await ensureSystemProxyConsistencyOnFirstLaunchIfNeeded()
            }
        }
        if startBackgroundRefresh && autoStartCore {
            Task { [weak self] in
                await self?.attemptAutoStartIfNeeded()
            }
        }

        refreshMenuBarDisplaySnapshotIfNeeded()
    }

    deinit {
        mediumFrequencyTask?.cancel()
        lowFrequencyTask?.cancel()
        for task in streamReceiveTasks.values {
            task.cancel()
        }
        for webSocketTask in streamWebSocketTasks.values {
            webSocketTask.cancel(with: .goingAway, reason: nil)
        }
        providerRefreshTask?.cancel()
    }
}
