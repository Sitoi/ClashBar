import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var statusText: String = "Stopped" {
        didSet { self.refreshMenuBarDisplaySnapshotIfNeeded() }
    }

    @Published var version: String = "-"
    @Published var controller: String = "127.0.0.1:9090"
    @Published var externalControllerDisplay: String = "127.0.0.1:9090"
    var localExternalControllerDisplay: String = "127.0.0.1:9090"
    @Published var controllerUIURL: String =
        "https://metacubex.github.io/metacubexd/#/setup?http=true&hostname=127.0.0.1&port=9090&secret="
    @Published var controllerSecret: String?
    var hasConfiguredExternalUI = false
    var configuredExternalUIName: String?

    let trafficStore = TrafficStore()
    var traffic: TrafficSnapshot {
        get { self.trafficStore.traffic }
        set { self.trafficStore.traffic = newValue }
    }

    var memory: MemorySnapshot {
        get { self.trafficStore.memory }
        set { self.trafficStore.memory = newValue }
    }

    var displayUpTotal: Int64 {
        get { self.trafficStore.displayUpTotal }
        set { self.trafficStore.displayUpTotal = newValue }
    }

    var displayDownTotal: Int64 {
        get { self.trafficStore.displayDownTotal }
        set { self.trafficStore.displayDownTotal = newValue }
    }

    var trafficHistoryUp: [Int64] {
        get { self.trafficStore.trafficHistoryUp }
        set { self.trafficStore.trafficHistoryUp = newValue }
    }

    var trafficHistoryDown: [Int64] {
        get { self.trafficStore.trafficHistoryDown }
        set { self.trafficStore.trafficHistoryDown = newValue }
    }

    var connectionsCount: Int {
        self.connectionsStore.connectionsCount
    }

    var connections: [ConnectionSummary] {
        self.connectionsStore.connections
    }

    let connectionsStore = ConnectionsStore()

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
    @Published var remoteConfigMenuStates: [String: RemoteConfigMenuState] = [:]
    @Published var isPinned: Bool = false

    func togglePinned() {
        self.isPinned.toggle()
    }

    let proxyStore = ProxyStore()
    var proxyGroups: [ProxyGroup] {
        get { self.proxyStore.proxyGroups }
        set { self.proxyStore.proxyGroups = newValue }
    }

    var groupLatencyLoading: Set<String> {
        get { self.proxyStore.groupLatencyLoading }
        set { self.proxyStore.groupLatencyLoading = newValue }
    }

    var proxyLatencyTesting: Set<ProxyLatencyTestKey> {
        get { self.proxyStore.proxyLatencyTesting }
        set { self.proxyStore.proxyLatencyTesting = newValue }
    }

    var proxyDelaySamples: [String: [Int]] {
        get { self.proxyStore.proxyDelaySamples }
        set { self.proxyStore.proxyDelaySamples = newValue }
    }

    var proxyNodeTypes: [String: String] {
        get { self.proxyStore.proxyNodeTypes }
        set { self.proxyStore.proxyNodeTypes = newValue }
    }

    var providerProxyCount: Int {
        get { self.proxyStore.providerProxyCount }
        set { self.proxyStore.providerProxyCount = newValue }
    }

    var providerRuleCount: Int {
        get { self.proxyStore.providerRuleCount }
        set { self.proxyStore.providerRuleCount = newValue }
    }

    var rulesCount: Int {
        get { self.proxyStore.rulesCount }
        set { self.proxyStore.rulesCount = newValue }
    }

    var proxyProvidersDetail: [String: ProviderDetail] {
        get { self.proxyStore.proxyProvidersDetail }
        set { self.proxyStore.proxyProvidersDetail = newValue }
    }

    var sortedProxyProviderNames: [String] {
        self.proxyStore.sortedProxyProviderNames
    }

    var providerUpdating: Set<String> {
        get { self.proxyStore.providerUpdating }
        set { self.proxyStore.providerUpdating = newValue }
    }

    var ruleProviders: [String: ProviderDetail] {
        get { self.proxyStore.ruleProviders }
        set { self.proxyStore.ruleProviders = newValue }
    }

    var ruleItems: [RuleItem] {
        get { self.proxyStore.ruleItems }
        set { self.proxyStore.ruleItems = newValue }
    }

    var isRuleProvidersRefreshing: Bool {
        get { self.proxyStore.isRuleProvidersRefreshing }
        set { self.proxyStore.isRuleProvidersRefreshing = newValue }
    }

    @Published var isSystemProxyEnabled: Bool = false
    @Published var systemProxyEnableIntentInFlight: Bool = false
    @Published var systemProxyHelperFailureReason: SystemProxyHelperFailureReason?
    @Published var systemProxyHelperFailureMessage: String?
    @Published var systemProxyBackgroundActivityAllowed: Bool?
    @Published var systemProxyHelperProcessRunning: Bool?
    @Published var systemProxyActiveDisplay: String?
    @Published var systemProxyOpenFailureHint: String?
    @Published var systemProxyExceptions: [EditableSystemProxyException] = []
    @Published var systemProxyNewException: String = ""
    @Published var ssidStrategyRules: [SSIDStrategyRule] = []
    @Published var ssidStrategyCurrentSSID: String?
    @Published var ssidStrategyAuthorizationStatus: SSIDMonitorAuthorizationStatus = .notDetermined
    @Published var statusItemBanner: StatusItemBanner?

    var isProxySyncing: Bool {
        get { self.proxyStore.isProxySyncing }
        set { self.proxyStore.isProxySyncing = newValue }
    }

    @Published var isTunEnabled: Bool = false
    @Published var isTunSyncing: Bool = false

    @Published var apiStatus: APIHealth = .unknown {
        didSet { self.refreshMenuBarDisplaySnapshotIfNeeded() }
    }

    let logsStore = LogsStore()
    var errorLogs: [AppErrorLogEntry] {
        get { self.logsStore.errorLogs }
        set { self.logsStore.errorLogs = newValue }
    }

    var startupErrorMessage: String? {
        get { self.logsStore.startupErrorMessage }
        set { self.logsStore.startupErrorMessage = newValue }
    }

    @Published var coreActionState: CoreActionState = .idle
    @Published var coreUpgradeState: CoreUpgradeState = .idle
    @Published var geoUpdateState: GeoUpdateState = .idle
    var providerRefreshStatus: ProviderRefreshStatus {
        get { self.proxyStore.providerRefreshStatus }
        set { self.proxyStore.providerRefreshStatus = newValue }
    }

    @Published var uiLanguage: AppLanguage = .zhHans
    @Published var appearanceMode: AppAppearanceMode = .system
    @Published var isPanelPresented: Bool = false
    @Published var activeMenuTab: RootTab = .proxy
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginErrorMessage: String?
    @Published var latestAppReleaseInfo: AppReleaseInfo?
    @Published private(set) var menuBarDisplaySnapshot = MenuBarDisplay(
        mode: .iconOnly,
        symbolName: "bolt.slash.circle",
        speedLines: nil,
        isRunning: false)

    @Published var settingsAllowLan: Bool = false
    @Published var settingsIPv6: Bool = false
    @Published var settingsTCPConcurrent: Bool = false
    @Published var settingsLogLevel: String = ConfigLogLevel.info.rawValue
    @Published var settingsPort: String = "0"
    @Published var settingsSocksPort: String = "0"
    @Published var settingsMixedPort: String = "7890"
    @Published var settingsRedirPort: String = "0"
    @Published var settingsTProxyPort: String = "0"

    @Published var settingsSyncingKey: String?
    var isCoreSettingSyncing: Bool {
        self.settingsSyncingKey != nil
    }

    @Published var settingsErrorMessage: String?
    @Published var settingsSavedMessage: String?
    var lastSyncedEditableSettings: EditableSettingsSnapshot?
    var preserveLocalSettingsOnNextSync = false
    var pendingConfigSwitchOverlaySettings: EditableSettingsSnapshot?
    var pendingAppLaunchOverlaySettings: EditableSettingsSnapshot?
    var suppressSettingsPersistence = false

    var runtimeVisualStatus: RuntimeVisualStatus {
        let normalized = self.statusText.lowercased()
        if normalized == "starting" {
            return .starting
        }
        if normalized == "failed" {
            return .failed
        }
        guard self.coreRepository.isRunning || normalized == "running" else { return .stopped }
        switch self.apiStatus {
        case .healthy: return .runningHealthy
        case .failed: return .failed
        case .degraded, .unknown: return .runningDegraded
        }
    }

    var runtimeStatusText: String {
        switch self.runtimeVisualStatus {
        case .starting: tr("app.runtime.starting")
        case .runningHealthy, .runningDegraded: tr("app.runtime.running")
        case .failed: tr("app.runtime.failed")
        case .stopped: tr("app.runtime.stopped")
        }
    }

    var isExternalControllerWildcardIPv4: Bool {
        guard let host = self.controllerHost(from: self.externalControllerDisplay) else {
            return false
        }
        return host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "0.0.0.0"
    }

    var isRuntimeRunning: Bool {
        self.coreRepository.isRunning || self.statusText.caseInsensitiveCompare("running") == .orderedSame
    }

    var menuBarSymbolName: String {
        switch self.runtimeVisualStatus {
        case .runningHealthy: "bolt.horizontal.circle.fill"
        case .runningDegraded: "bolt.horizontal.circle"
        case .starting: "clock.arrow.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        case .stopped: "bolt.slash.circle"
        }
    }

    var statusBarDisplayMode: StatusBarDisplayMode {
        get { StatusBarDisplayMode(rawValue: self.statusBarDisplayModeRaw) ?? .iconOnly }
        set {
            guard self.statusBarDisplayModeRaw != newValue.rawValue else { return }
            self.statusBarDisplayModeRaw = newValue.rawValue
            self.refreshMenuBarDisplaySnapshotIfNeeded()
            self.updateDataAcquisitionPolicy()
            if newValue != .iconOnly {
                self.flushPendingTrafficSnapshotIfNeeded(immediately: true)
            }
        }
    }

    var menuBarSpeedLines: MenuBarSpeedLines {
        guard self.isRuntimeRunning else { return .zero }

        let up = self.compactMenuBarRate(max(0, self.traffic.up))
        let down = self.compactMenuBarRate(max(0, self.traffic.down))
        return MenuBarSpeedLines(up: "\(up)↑", down: "\(down)↓")
    }

    private var computedMenuBarDisplay: MenuBarDisplay {
        let mode = self.statusBarDisplayMode
        return MenuBarDisplay(
            mode: mode,
            symbolName: mode == .speedOnly ? nil : self.menuBarSymbolName,
            speedLines: mode == .iconOnly ? nil : self.menuBarSpeedLines,
            isRunning: self.isRuntimeRunning)
    }

    func compactMenuBarRate(_ bytesPerSecond: Int64) -> String {
        let normalizedBytes = max(0, bytesPerSecond)
        guard normalizedBytes > 0 else { return "0K" }
        var value = Double(normalizedBytes) / 1024
        let units = ["K", "M", "G", "T"]
        var unitIndex = 0
        while value >= 1000, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        let format = value < 10 ? "%.2f%@" : (value < 100 ? "%.1f%@" : "%.0f%@")
        return String(format: format, min(value, 999), units[unitIndex])
    }

    func refreshMenuBarDisplaySnapshotIfNeeded() {
        let next = self.computedMenuBarDisplay
        guard next != self.menuBarDisplaySnapshot else { return }
        self.menuBarDisplaySnapshot = next
    }

    var isRemoteTarget: Bool {
        !self.remoteMachineStore.activeTarget.isLocal
    }

    var isModeSwitchEnabled: Bool {
        (self.isRemoteTarget || self.coreRepository.isRunning) && self.apiStatus == .healthy
    }

    var isTunToggleEnabled: Bool {
        (self.isRemoteTarget || self.isRuntimeRunning) && !self.isCoreActionProcessing && !self.isTunSyncing
    }

    var autoStartCoreEnabled: Bool {
        get { self.autoStartCore }
        set { self.autoStartCore = newValue }
    }

    var isCoreActionProcessing: Bool {
        self.coreActionState != .idle
    }

    var primaryCoreActionLabel: String {
        if self.isCoreActionProcessing {
            return tr("app.primary.processing")
        }
        return self.isRuntimeRunning ? tr("app.primary.restart") : tr("app.primary.start")
    }

    var primaryCoreActionIconName: String {
        if self.isCoreActionProcessing {
            return "hourglass"
        }
        return self.isRuntimeRunning ? "arrow.clockwise" : "play.fill"
    }

    var isPrimaryCoreActionEnabled: Bool {
        !self.isCoreActionProcessing
    }

    let processManager: any MihomoControlling
    let coreRepository: any CoreRepository
    let configRepository: any ConfigRepository
    let systemProxyRepository: any SystemProxyRepository
    let tunPermissionRepository: any TunPermissionRepository
    let launchAtLoginRepository: any LaunchAtLoginRepository
    let workingDirectoryManager: WorkingDirectoryManager
    let networkReachabilityMonitor: NetworkReachabilityMonitor
    let ssidMonitorService: SSIDMonitorService
    let remoteMachineStore: RemoteMachineStore
    let proxyGroupIconCache: ProxyGroupIconCache
    var apiClient: MihomoAPIService?

    var mediumFrequencyTask: Task<Void, Never>?
    var lowFrequencyTask: Task<Void, Never>?
    let streamCoordinator = StreamCoordinator()
    var proxyPortsAutoSaveTask: Task<Void, Never>?
    var settingsFeedbackClearTask: Task<Void, Never>?
    var providerRefreshTask: Task<Void, Never>?
    var networkAutoStopTask: Task<Void, Never>?
    var networkAutoStartTask: Task<Void, Never>?
    var deferredEditableSettingsOverlayTask: Task<Void, Never>?
    var coreUpgradeFeedbackClearTask: Task<Void, Never>?
    var geoUpdateFeedbackClearTask: Task<Void, Never>?
    var configDirectoryMonitor: ConfigDirectoryMonitor?
    var trafficDecodeTask: Task<Void, Never>?
    var mihomoLogFlushTask: Task<Void, Never>?
    var startupRefreshTask: Task<Void, Never>?
    var autoStartTask: Task<Void, Never>?
    var configDirectoryDebounceTask: Task<Void, Never>?
    var providerRefreshGeneration: Int = 0
    var lastTrafficSampleAt: Date?
    var lastTrafficDecodeAt: Date = .distantPast
    var lastSavedSystemProxyExceptions: [String] = []
    var pendingTrafficPayload: Data?
    var pendingMihomoLogs: [AppErrorLogEntry] = []
    var modeSwitchInFlight = false

    var proxyProvidersAPIUnavailableLogged = false
    var lastAPIRefreshErrorFingerprint: String?
    var didStart = false
    var activatedTabRefreshGeneration: Int = 0
    var configFileSignatureSnapshot: [String: String] = [:]
    var pendingConfigChangeRestart = false
    var isLatestAppReleaseCheckInFlight = false

    let defaults = UserDefaults.standard
    @AppStorage("clashbar.auto.start.core") var autoStartCore: Bool = false
    @AppStorage("clashbar.ssid.strategy.enabled") var ssidStrategyEnabledStorage: Bool = false
    @AppStorage("clashbar.statusbar.display.mode") private var statusBarDisplayModeRaw: String = StatusBarDisplayMode
        .iconOnly.rawValue
    @AppStorage("clashbar.proxy.node.hide_unavailable") var hideUnavailableProxyNodes: Bool = false
    let selectedConfigKey = "clashbar.config.selected.filename"
    let legacySelectedConfigKey = "clashbar.config.selected"
    let remoteConfigSourcesKey = "clashbar.config.remote.sources.v1"
    let remoteConfigSubscriptionsKey = "clashbar.config.remote.subscriptions.v2"
    let lastSuccessfulConfigPathKey = "clashbar.last.success.config.path"
    let editableSettingsSnapshotKey = "clashbar.settings.editable.snapshot.v1"
    let systemProxyEnabledOnQuitKey = "clashbar.system_proxy.enabled_on_quit"
    let systemProxyExceptionsKey = "clashbar.system_proxy.exceptions.v1"
    let ssidStrategyRulesKey = "clashbar.ssid.strategy.rules.v1"
    let uiLanguageKey = "clashbar.ui.language"
    let appearanceModeKey = "clashbar.ui.appearance.mode"

    let maxInMemoryLogEntries = 5000
    let hiddenPanelMaxInMemoryLogEntries = 20

    let maxBufferedMihomoLogEntries = 40
    let historyMaxPoints = 60
    let mihomoLogFlushIntervalNanoseconds: UInt64 = 150_000_000
    let foregroundMediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    let backgroundMediumFrequencyIntervalNanoseconds: UInt64 = 12_000_000_000
    let foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: UInt64 = 20_000_000_000
    let foregroundLowFrequencyOtherTabsIntervalNanoseconds: UInt64 = 45_000_000_000
    let backgroundLowFrequencyIntervalNanoseconds: UInt64 = 120_000_000_000
    let trafficPublishIntervalNanoseconds: UInt64 = 500_000_000

    let defaultHealthcheckURL = "https://www.gstatic.com/generate_204"
    let defaultHealthcheckTimeoutMilliseconds = 5000
    var mediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    var lowFrequencyIntervalNanoseconds: UInt64 = 20_000_000_000
    var currentConnectionsStreamIntervalMilliseconds: Int?
    var currentLogsStreamLevel: String?
    var clashbarLogFileURL: URL?
    var mihomoLogFileURL: URL?
    var clashbarLogStore: AppLogStore?
    var mihomoLogStore: AppLogStore?
    var didAttemptAutoStart = false
    var didCheckSystemProxyConsistencyOnLaunch = false
    var lastCoreFailureAlertKey: String?
    var lastCoreFailureAlertAt: Date?
    let coreFailureAlertThrottleInterval: TimeInterval = 20
    var networkReachabilityStatus: NetworkReachabilityStatus = .unknown
    var shouldResumeCoreAfterNetworkRecovery = false
    var isNetworkReachabilityMonitoring = false
    var isSSIDStrategyMonitoring = false
    var pendingCoreFeatureRecoveryState: CoreFeatureRecoveryState?
    var deferredEditableSettingsOverlay: (snapshot: EditableSettingsSnapshot, syncingKey: String)?
    var remoteConfigSubscriptions: [String: RemoteConfigSubscription] = [:]
    var ssidStrategyLastLogFingerprint: String?
    var pendingSSIDBindingConfigFileName: String?
    var ssidStrategyApplyTask: Task<Void, Never>?
    var remoteConfigAutoUpdateTask: Task<Void, Never>?
    var remoteConfigMenuRefreshTask: Task<Void, Never>?
    var externalControllerWarningKeys: Set<String> = []
    let streamJSONDecoder = JSONDecoder()
    let initialNoCoreSetupGuideShownKey = "clashbar.core.install.guide.shown.v1"
    let bundlesMihomoCore: Bool
    var didPresentInitialNoCoreSetupGuide = false

    init(dependencies: AppDependencies) {
        self.processManager = dependencies.processManager
        self.coreRepository = dependencies.coreRepository
        self.configRepository = dependencies.configRepository
        self.systemProxyRepository = dependencies.systemProxyRepository
        self.tunPermissionRepository = dependencies.tunPermissionRepository
        self.launchAtLoginRepository = dependencies.launchAtLoginRepository
        self.workingDirectoryManager = dependencies.workingDirectoryManager
        self.networkReachabilityMonitor = dependencies.networkReachabilityMonitor
        self.ssidMonitorService = dependencies.ssidMonitorService
        self.remoteMachineStore = dependencies.remoteMachineStore
        self.proxyGroupIconCache = dependencies.proxyGroupIconCache
        self.clashbarLogStore = dependencies.clashbarLogStore
        self.mihomoLogStore = dependencies.mihomoLogStore
        self.clashbarLogFileURL = dependencies.clashbarLogStore.logFileURL
        self.mihomoLogFileURL = dependencies.mihomoLogStore.logFileURL
        self.bundlesMihomoCore = Self.resolveBundledMihomoCoreFlag()
        self.uiLanguage = loadPersistedUILanguage()
        self.appearanceMode = loadPersistedAppearanceMode()
        applyAppAppearance()
        configureStreamCoordinator()
        refreshLaunchAtLoginStatus()
        self.configureManagedProcessCallbacks()
    }

    isolated deinit {
        self.cancelOwnedTasks()
    }
}
