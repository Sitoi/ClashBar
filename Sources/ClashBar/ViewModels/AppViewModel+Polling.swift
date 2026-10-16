import Foundation

@MainActor
extension AppViewModel {
    func startPolling() {
        self.teardownStreams()
        self.ensurePeriodicTasksForCurrentVisibility()
        self.updateDataAcquisitionPolicy()
    }

    func cancelPolling() {
        self.teardownStreams()
    }

    private func teardownStreams() {
        mediumFrequencyTask?.cancel()
        lowFrequencyTask?.cancel()
        for kind in StreamKind.allCases {
            cancelStream(kind)
        }
        mediumFrequencyTask = nil
        lowFrequencyTask = nil
        currentConnectionsStreamIntervalMilliseconds = nil
    }

    private func startPeriodicTask(
        intervalProvider: @escaping (AppViewModel) -> UInt64,
        operation: @escaping (AppViewModel) async -> Void) -> Task<Void, Never>
    {
        Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await operation(self)
                do {
                    let interval = max(1_000_000_000, intervalProvider(self))
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
            }
        }
    }

    private func ensurePeriodicTasksForCurrentVisibility() {
        guard isPanelPresented else {
            mediumFrequencyTask?.cancel()
            mediumFrequencyTask = nil
            lowFrequencyTask?.cancel()
            lowFrequencyTask = nil
            return
        }
        if mediumFrequencyTask == nil {
            mediumFrequencyTask = self.startPeriodicTask(
                intervalProvider: { $0.mediumFrequencyIntervalNanoseconds },
                operation: { await $0.refreshMediumFrequency() })
        }
        if lowFrequencyTask == nil {
            lowFrequencyTask = self.startPeriodicTask(
                intervalProvider: { $0.lowFrequencyIntervalNanoseconds },
                operation: { await $0.refreshLowFrequency() })
        }
    }

    func refreshFromAPI(includeSlowCalls: Bool) async {
        await self.refreshHighFrequency()
        await self.refreshMediumFrequency()
        if includeSlowCalls {
            await self.refreshLowFrequency()
        }
    }

    private func refreshHighFrequency() async {
        self.updateDataAcquisitionPolicy()
    }

    func setPanelVisibility(_ presented: Bool) {
        guard isPanelPresented != presented else { return }
        isPanelPresented = presented
        if !presented {
            cancelProxyPortsAutoSave()
            self.resetTrafficTotalsForHiddenPanel()
            self.releasePanelCachedData()
        }
        trimInMemoryLogsForCurrentVisibility()
        self.updateDataAcquisitionPolicy()

        guard presented else { return }
        self.flushPendingTrafficSnapshotIfNeeded(immediately: true)
        self.scheduleRefreshForActivatedTab(activeMenuTab)
        Task { [weak self] in
            await self?.refreshLatestAppRelease()
        }
    }

    func setActiveMenuTab(_ tab: RootTab) {
        let changed = activeMenuTab != tab
        activeMenuTab = tab
        self.updateDataAcquisitionPolicy()

        guard changed else { return }
        self.scheduleRefreshForActivatedTab(tab)
    }

    private func scheduleRefreshForActivatedTab(_ tab: RootTab) {
        activatedTabRefreshGeneration += 1
        let generation = activatedTabRefreshGeneration
        Task { [weak self] in
            guard let self else { return }
            await self.refreshForActivatedTab(tab, generation: generation)
        }
    }

    private func desiredDataAcquisitionPolicy(
        panelPresented: Bool,
        activeTab: RootTab) -> DataAcquisitionPolicy
    {
        let trafficEnabled = panelPresented || self.statusBarDisplayMode != .iconOnly

        if !panelPresented {
            return DataAcquisitionPolicy(
                enableTrafficStream: trafficEnabled,
                enableMemoryStream: false,
                enableConnectionsStream: true,
                connectionsIntervalMilliseconds: 1000,
                enableLogsStream: false,
                mediumFrequencyIntervalNanoseconds: self.backgroundMediumFrequencyIntervalNanoseconds,
                lowFrequencyIntervalNanoseconds: self.backgroundLowFrequencyIntervalNanoseconds)
        }

        let lowFrequencyInterval: UInt64 = switch activeTab {
        case .proxy, .rules:
            self.foregroundLowFrequencyPrimaryTabsIntervalNanoseconds
        default:
            self.foregroundLowFrequencyOtherTabsIntervalNanoseconds
        }

        let memoryEnabled = activeTab == .proxy
        let logsEnabled = activeTab == .logs

        return DataAcquisitionPolicy(
            enableTrafficStream: trafficEnabled,
            enableMemoryStream: memoryEnabled,
            enableConnectionsStream: true,
            connectionsIntervalMilliseconds: 1000,
            enableLogsStream: logsEnabled,
            mediumFrequencyIntervalNanoseconds: self.foregroundMediumFrequencyIntervalNanoseconds,
            lowFrequencyIntervalNanoseconds: lowFrequencyInterval)
    }

    func updateDataAcquisitionPolicy() {
        guard self.isRemoteTarget || self.processManager.isRunning else {
            self.ensurePeriodicTasksForCurrentVisibility()
            mediumFrequencyIntervalNanoseconds = foregroundMediumFrequencyIntervalNanoseconds
            lowFrequencyIntervalNanoseconds = foregroundLowFrequencyPrimaryTabsIntervalNanoseconds
            return
        }

        let policy = self.desiredDataAcquisitionPolicy(
            panelPresented: isPanelPresented,
            activeTab: activeMenuTab)

        mediumFrequencyIntervalNanoseconds = policy.mediumFrequencyIntervalNanoseconds
        lowFrequencyIntervalNanoseconds = policy.lowFrequencyIntervalNanoseconds
        self.ensurePeriodicTasksForCurrentVisibility()
        self.applyStreamPolicy(policy)
    }

    func refreshForActivatedTab(_ tab: RootTab, generation: Int? = nil) async {
        guard self.isRemoteTarget || self.processManager.isRunning else { return }

        func shouldContinueRefresh() -> Bool {
            guard let generation else { return true }
            return generation == activatedTabRefreshGeneration
        }

        guard shouldContinueRefresh() else { return }

        switch tab {
        case .proxy:
            await self.refreshMediumFrequency()
            guard shouldContinueRefresh() else { return }
            if proxyProvidersDetail.isEmpty || ruleItems.isEmpty {
                await refreshProvidersAndRules()
            }
        case .rules:
            await refreshProvidersAndRules()
        case .connections:
            await self.refreshConnections()
        case .logs:
            break
        case .system:
            await self.refreshMediumFrequency()
            guard shouldContinueRefresh() else { return }
            if !self.isRemoteTarget, self.hasSystemProxyOpenIntent {
                await self.refreshSystemProxyStatus()
            }
        }
    }

    private func fetchProxyProvidersSummarySafely(client: any MihomoAPITransporting) async
    -> (providers: [String: ProviderDetail], error: Error?) {
        do {
            let providers: ProviderSummary = try await client.request(.proxyProviders)
            return (providers.providers, nil)
        } catch {
            return ([:], error)
        }
    }

    private func refreshMediumFrequency() async {
        await runRefresh {
            let client = try self.clientOrThrow()
            async let versionTask: VersionInfo = client.request(.version)
            async let configTask: ConfigSnapshot = client.request(.getConfigs)

            if self.activeMenuTab == .proxy {
                async let proxyGroupsTask: ProxyGroupsResponse = client.request(.proxies)
                async let providersTask = self.fetchProxyProvidersSummarySafely(client: client)

                let (versionInfo, configSnapshot, resolvedGroups, providersResult) = try await (
                    versionTask,
                    configTask,
                    proxyGroupsTask,
                    providersTask)

                self.version = versionInfo.version
                self.applyRuntimeConfigSnapshot(configSnapshot)
                self.noteProxyProvidersAPIAvailability(error: providersResult.error)
                self.applyProxyGroupsResponse(
                    resolvedGroups,
                    proxyProviders: providersResult.providers)
            } else {
                let (versionInfo, configSnapshot) = try await (versionTask, configTask)
                self.version = versionInfo.version
                self.applyRuntimeConfigSnapshot(configSnapshot)
            }
        }
    }

    func fetchRuntimeConfigSnapshot() async throws -> ConfigSnapshot {
        let client = try clientOrThrow()
        let config: ConfigSnapshot = try await client.request(.getConfigs)
        self.applyRuntimeConfigSnapshot(config)
        return config
    }

    private func applyRuntimeConfigSnapshot(_ config: ConfigSnapshot) {
        let remoteMode = normalizeMode(config.mode)
        if let remoteMode {
            currentMode = remoteMode
        }
        logLevel = config.logLevel ?? logLevel

        port = config.port
        socksPort = config.socksPort
        redirPort = config.redirPort
        tproxyPort = config.tproxyPort
        mixedPort = config.mixedPort ?? 0

        tunStack = config.tun?.stack?.trimmedNonEmpty ?? tunStack

        if !self.isRemoteTarget, let externalController = config.externalController {
            applyExternalControllerFromConfig(externalController)
        }
        if self.isRemoteTarget || config.externalUIURL != nil || config.externalUIName != nil {
            self.applyExternalUIConfiguration(
                hasURL: config.externalUIURL.trimmedNonEmpty != nil,
                name: config.externalUIName)
        }
        syncEditableSettings(from: config)
        refreshLogsStreamLevelIfNeeded()
    }

    func resetTrafficPresentation() {
        traffic = TrafficSnapshot(up: 0, down: 0)
        self.clearTrafficPresentationHistory()
    }

    func clearProxyPresentation() {
        proxyGroups = []
        proxyDelaySamples = [:]
        proxyNodeTypes = [:]
        groupLatencyLoading = []
        proxyLatencyTesting = []
        providerProxyCount = 0
        proxyProvidersDetail = [:]
        providerUpdating = []
    }

    func clearTrafficPresentationHistory() {
        displayUpTotal = 0
        displayDownTotal = 0
        trafficHistoryUp = []
        trafficHistoryDown = []
        trafficHistoryUp.reserveCapacity(historyMaxPoints)
        trafficHistoryDown.reserveCapacity(historyMaxPoints)
        lastTrafficSampleAt = nil
    }

    func resetTrafficTotalsForHiddenPanel() {
        displayUpTotal = 0
        displayDownTotal = 0
        lastTrafficSampleAt = nil
    }

    private func releasePanelCachedData() {
        connectionsStore.connectionsCount = 0
        connectionsStore.connections.removeAll(keepingCapacity: false)
        connectionsStore.statistics = .empty

        memory = MemorySnapshot(inuse: 0)

        groupLatencyLoading.removeAll(keepingCapacity: false)
        proxyLatencyTesting.removeAll(keepingCapacity: false)

        providerRuleCount = 0
        rulesCount = 0
        ruleProviders.removeAll(keepingCapacity: false)
        ruleItems.removeAll(keepingCapacity: false)
    }

    func appendTrafficHistory(up: Int64, down: Int64) {
        trafficHistoryUp.append(max(0, up))
        trafficHistoryDown.append(max(0, down))

        if trafficHistoryUp.count > historyMaxPoints {
            trafficHistoryUp.removeFirst(trafficHistoryUp.count - historyMaxPoints)
        }
        if trafficHistoryDown.count > historyMaxPoints {
            trafficHistoryDown.removeFirst(trafficHistoryDown.count - historyMaxPoints)
        }
    }

    func updateTrafficTotals(from snapshot: TrafficSnapshot) {
        if let upTotal = snapshot.upTotal, let downTotal = snapshot.downTotal {
            displayUpTotal = max(0, upTotal)
            displayDownTotal = max(0, downTotal)
            lastTrafficSampleAt = Date()
            return
        }

        let now = Date()
        if let last = lastTrafficSampleAt {
            let delta = max(0, now.timeIntervalSince(last))
            displayUpTotal += Int64(Double(max(0, snapshot.up)) * delta)
            displayDownTotal += Int64(Double(max(0, snapshot.down)) * delta)
        }
        lastTrafficSampleAt = now
    }

    private func refreshLowFrequency() async {
        switch activeMenuTab {
        case .proxy:
            await refreshProvidersAndRules()
            if !self.isRemoteTarget {
                await self.refreshSystemProxyStatus()
            }
        case .rules:
            await refreshProvidersAndRules()
        case .system:
            if !self.isRemoteTarget {
                await self.refreshSystemProxyStatus()
            }
        case .connections, .logs:
            break
        }
    }

    func refreshProxyGroups() async {
        await runRefresh {
            let client = try self.clientOrThrow()
            async let groupsTask: ProxyGroupsResponse = client.request(.proxies)
            async let providersTask = self.fetchProxyProvidersSummarySafely(client: client)

            let (resolvedGroups, providersResult) = try await (groupsTask, providersTask)
            self.noteProxyProvidersAPIAvailability(error: providersResult.error)
            self.applyProxyGroupsResponse(resolvedGroups, proxyProviders: providersResult.providers)
        }
    }

    private func noteProxyProvidersAPIAvailability(error: Error?) {
        if let error {
            guard !self.proxyProvidersAPIUnavailableLogged else { return }
            self.proxyProvidersAPIUnavailableLogged = true
            self.appendLog(
                level: "info",
                message: tr("log.providers.api_unavailable", error.localizedDescription))
        } else if self.proxyProvidersAPIUnavailableLogged {
            self.proxyProvidersAPIUnavailableLogged = false
        }
    }

    private func applyProxyGroupsResponse(
        _ response: ProxyGroupsResponse,
        proxyProviders: [String: ProviderDetail] = [:])
    {
        let providerLookup = proxyProviders.isEmpty ? self.proxyProvidersDetail : proxyProviders
        let proxiesWithHealthcheckConfig = response.proxies.values.map { proxy in
            let provider = providerLookup[proxy.name]
            let resolvedTestURL = proxy.testUrl?.trimmedNonEmpty ?? provider?.testUrl?.trimmedNonEmpty
            let resolvedTimeout = proxy.timeout.flatMap { $0 > 0 ? $0 : nil }
                ?? provider?.timeout.flatMap { $0 > 0 ? $0 : nil }

            return ProxyGroup(
                name: proxy.name,
                type: proxy.type,
                now: proxy.now,
                all: proxy.all,
                testUrl: resolvedTestURL,
                timeout: resolvedTimeout,
                icon: proxy.icon,
                hidden: proxy.hidden,
                delayHistory: proxy.delayHistory)
        }

        let sortIndex = (response.proxies["GLOBAL"]?.all ?? []) + ["GLOBAL"]
        var sortIndexMap: [String: Int] = [:]
        for (index, name) in sortIndex.enumerated() where sortIndexMap[name] == nil {
            sortIndexMap[name] = index
        }

        let groups = proxiesWithHealthcheckConfig
            .enumerated()
            .filter { !$0.element.all.isEmpty }
            .sorted { lhs, rhs in
                let lhsOrder = sortIndexMap[lhs.element.name] ?? .max
                let rhsOrder = sortIndexMap[rhs.element.name] ?? .max

                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }

                return lhs.element.name.localizedCaseInsensitiveCompare(rhs.element.name) == .orderedAscending
            }
            .map(\.element)

        var delaySamples: [String: [Int]] = [:]
        var nodeTypes: [String: String] = [:]
        for proxy in response.proxies.values {
            if proxy.all.isEmpty, let type = proxy.type.trimmedNonEmpty {
                nodeTypes[proxy.name] = type
            }
            if !proxy.delayHistory.isEmpty {
                delaySamples[proxy.name] = proxy.delayHistory
            }
        }

        for provider in providerLookup.values {
            for node in provider.proxies ?? [] {
                if !node.delayHistory.isEmpty, delaySamples[node.name] == nil {
                    delaySamples[node.name] = node.delayHistory
                }
                if let type = node.type.trimmedNonEmpty, nodeTypes[node.name] == nil {
                    nodeTypes[node.name] = type
                }
            }
        }

        self.proxyGroups = groups
        self.proxyDelaySamples = Self.mergeProxyDelaySamples(
            api: delaySamples,
            previous: self.proxyDelaySamples)
        self.proxyNodeTypes = nodeTypes
    }

    private static func mergeProxyDelaySamples(
        api: [String: [Int]],
        previous: [String: [Int]]) -> [String: [Int]]
    {
        var merged = api
        for (name, existing) in previous {
            guard !existing.isEmpty else { continue }
            guard let apiSamples = api[name], !apiSamples.isEmpty else {
                merged[name] = Array(existing.suffix(ProxyDelayHistory.limit))
                continue
            }
            merged[name] = Self.mergeDelaySeries(api: apiSamples, previous: existing)
        }
        return merged
    }

    private static func mergeDelaySeries(api: [Int], previous: [Int]) -> [Int] {
        let limit = ProxyDelayHistory.limit

        func overlap(from earlier: [Int], to later: [Int]) -> Int {
            let maximum = min(earlier.count, later.count)
            guard maximum > 0 else { return 0 }
            for count in stride(from: maximum, through: 1, by: -1)
                where earlier.suffix(count).elementsEqual(later.prefix(count))
            {
                return count
            }
            return 0
        }

        let previousFollowsAPI = overlap(from: api, to: previous)
        let apiFollowsPrevious = overlap(from: previous, to: api)

        if previousFollowsAPI > apiFollowsPrevious {
            let chosen = previous.count > previousFollowsAPI ? previous : api
            return Array(chosen.suffix(limit))
        }
        if apiFollowsPrevious > previousFollowsAPI {
            let chosen = api.count > apiFollowsPrevious ? api : previous
            return Array(chosen.suffix(limit))
        }
        if previousFollowsAPI > 0 {
            let chosen = previous.count >= api.count ? previous : api
            return Array(chosen.suffix(limit))
        }

        if previous.last == api.last {
            let chosen = previous.count >= api.count ? previous : api
            return Array(chosen.suffix(limit))
        }

        if previous.count >= api.count {
            return Array(previous.suffix(limit))
        }
        var stitched = api
        if let localLast = previous.last {
            stitched.append(localLast)
        }
        return Array(stitched.suffix(limit))
    }

    func refreshConnections() async {
        let policy = self.desiredDataAcquisitionPolicy(panelPresented: isPanelPresented, activeTab: activeMenuTab)
        guard policy.enableConnectionsStream else {
            cancelStream(.connections)
            return
        }
        self.syncConnectionsStream(
            enabled: true,
            intervalMilliseconds: policy.connectionsIntervalMilliseconds)
    }

    func refreshSystemProxyStatus() async {
        guard self.hasSystemProxyOpenIntent else {
            self.resetSystemProxyObservedState()
            return
        }

        do {
            let enabled = try await readSystemProxyEnabledState()
            isSystemProxyEnabled = enabled
            if enabled {
                systemProxyActiveDisplay = try await readSystemProxyActiveDisplay()
            } else {
                systemProxyActiveDisplay = nil
            }
            await self.refreshSystemProxyExceptionsFromSystemIfPossible()
            await self.refreshSystemProxyHelperRuntimeSnapshot()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.read_failed", systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
        }
    }

    private func applyStreamPolicy(_ policy: DataAcquisitionPolicy) {
        self.syncStream(.traffic, enabled: policy.enableTrafficStream) { startTrafficStream() }
        self.syncStream(.memory, enabled: policy.enableMemoryStream) { startMemoryStream() }
        self.syncConnectionsStream(
            enabled: policy.enableConnectionsStream,
            intervalMilliseconds: policy.connectionsIntervalMilliseconds)
        self.syncStream(
            .logs,
            enabled: policy.enableLogsStream,
            forceRestart: currentLogsStreamLevel != logsStreamLevelFilter())
        {
            startLogsStream()
        }
    }

    private func syncConnectionsStream(enabled: Bool, intervalMilliseconds: Int?) {
        self.syncStream(
            .connections,
            enabled: enabled,
            forceRestart: currentConnectionsStreamIntervalMilliseconds != intervalMilliseconds)
        {
            startConnectionsStream(intervalMilliseconds: intervalMilliseconds)
        }
    }

    private func syncStream(
        _ kind: StreamKind,
        enabled: Bool,
        forceRestart: Bool = false,
        start: () -> Void)
    {
        guard enabled else {
            cancelStream(kind)
            return
        }
        guard forceRestart || webSocketTask(for: kind) == nil else { return }
        start()
    }
}

extension AppViewModel {
    func runRefresh(_ block: () async throws -> Void) async {
        do {
            self.ensureAPIClient()
            try await block()
            if self.apiStatus != .healthy {
                self.apiStatus = .healthy
            }
            self.lastAPIRefreshErrorFingerprint = nil
        } catch {
            if self.apiStatus != .degraded {
                self.apiStatus = .degraded
            }
            let fingerprint = "\(String(reflecting: type(of: error))):\(error.localizedDescription)"
            guard self.lastAPIRefreshErrorFingerprint != fingerprint else { return }
            self.lastAPIRefreshErrorFingerprint = fingerprint
            self.appendLog(level: "error", message: error.localizedDescription)
        }
    }

    func runNoResponseAction(_ name: String, operation: () async throws -> Void) async {
        do {
            ensureAPIClient()
            try await operation()
            appendLog(level: "info", message: tr("log.action.success", name))
        } catch {
            appendLog(level: "error", message: tr("log.action.failed", name, error.localizedDescription))
        }
    }
}
