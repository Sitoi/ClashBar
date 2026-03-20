import Foundation

@MainActor
extension AppSession {
    private struct ProviderRefreshStatusUpdate {
        let phase: ProviderRefreshPhase
        let trigger: ProviderRefreshTrigger?
        let progressDone: Int
        let progressTotal: Int
        let message: String?
        let generation: Int
    }

    private func providersRepository() throws -> ProvidersRepository {
        try DefaultProvidersRepository(transport: self.clientOrThrow())
    }

    private func fetchProvidersAndRulesUseCase() throws -> FetchProvidersAndRulesUseCase {
        try FetchProvidersAndRulesUseCase(repository: self.providersRepository())
    }

    private func updateProxyProviderUseCase() throws -> UpdateProxyProviderUseCase {
        try UpdateProxyProviderUseCase(repository: self.providersRepository())
    }

    private func updateRuleProviderUseCase() throws -> UpdateRuleProviderUseCase {
        try UpdateRuleProviderUseCase(repository: self.providersRepository())
    }

    private func reloadProvidersConfigUseCase() throws -> ReloadProvidersConfigUseCase {
        try ReloadProvidersConfigUseCase(repository: self.providersRepository())
    }

    func updateRuleProvider(name: String) async {
        await self.runSingleProviderUpdate(
            actionName: tr("log.action_name.update_rule_provider", name),
            operation: {
                try await self.updateRuleProviderUseCase().execute(name: name)
            })
    }

    func refreshRuleProviders() async {
        guard !isRuleProvidersRefreshing else { return }
        isRuleProvidersRefreshing = true
        defer { isRuleProvidersRefreshing = false }

        do {
            let summary = try await self.providersRepository().fetchRuleProviders()
            let names = summary.providers.keys.sorted()
            _ = await self.updateProvidersSequential(
                names: names,
                operation: { name in
                    try await self.updateRuleProviderUseCase().execute(name: name)
                },
                onError: { name, error in
                    tr("log.providers.rule_update_failed", name, error.localizedDescription)
                })
        } catch {
            appendLog(level: "error", message: tr("log.providers.fetch_rule_failed", error.localizedDescription))
        }

        await self.refreshProvidersAndRules()
    }

    func updateProxyProvider(name: String) async {
        guard !providerUpdating.contains(name) else { return }
        providerUpdating.insert(name)
        defer { providerUpdating.remove(name) }

        await self.runSingleProviderUpdate(
            actionName: tr("log.action_name.update_proxy_provider", name),
            operation: {
                try await self.updateProxyProviderUseCase().execute(name: name)
            })
    }

    private func mergedProviderDetailPreservingNodes(
        previous: ProviderDetail?,
        incoming: ProviderDetail) -> ProviderDetail
    {
        let fallbackNodes = incoming.proxies?.map {
            ProviderProxyNode(name: $0.name, latestDelay: $0.latestDelay)
        }
        return incoming.with(proxies: previous?.proxies ?? fallbackNodes)
    }

    private func shouldIncludeProxyProvider(named key: String, detail: ProviderDetail) -> Bool {
        let resolvedName = detail.name.trimmedNonEmpty ?? key
        if resolvedName.caseInsensitiveCompare("default") == .orderedSame {
            return false
        }

        let vehicleType = detail.vehicleType.trimmedOrEmpty
        return vehicleType.caseInsensitiveCompare("Compatible") != .orderedSame
    }

    func enqueueProviderRefresh(trigger: ProviderRefreshTrigger) {
        self.cancelProviderRefresh(reason: "superseded")
        providerRefreshGeneration += 1
        let generation = providerRefreshGeneration
        providerRefreshTask = Task { [weak self] in
            await self?.runProviderRefreshInBackground(trigger: trigger, generation: generation)
        }
    }

    func cancelProviderRefresh(reason: String) {
        guard providerRefreshTask != nil else { return }
        providerRefreshTask?.cancel()
        providerRefreshTask = nil
        let localizedReason = self.providerRefreshCancelReason(reason)
        self.updateProviderRefreshStatus(
            ProviderRefreshStatusUpdate(
                phase: .cancelled,
                trigger: providerRefreshStatus.trigger,
                progressDone: providerRefreshStatus.progressDone,
                progressTotal: providerRefreshStatus.progressTotal,
                message: tr("app.provider_refresh.cancelled_reason", localizedReason),
                generation: providerRefreshGeneration))
    }

    private func runProviderRefreshInBackground(trigger: ProviderRefreshTrigger, generation: Int) async {
        func checkpoint() -> Bool {
            if Task.isCancelled || generation != providerRefreshGeneration {
                self.updateProviderRefreshStatus(
                    ProviderRefreshStatusUpdate(
                        phase: .cancelled,
                        trigger: trigger,
                        progressDone: providerRefreshStatus.progressDone,
                        progressTotal: providerRefreshStatus.progressTotal,
                        message: tr("app.provider_refresh.cancelled"),
                        generation: generation))
                return false
            }
            return true
        }

        guard checkpoint() else { return }

        func fetchProviderSummary(_ endpoint: Endpoint, onError: (Error) -> String) async -> ProviderSummary {
            do {
                switch endpoint {
                case .proxyProviders:
                    return try await self.providersRepository().fetchProxyProviders()
                case .ruleProviders:
                    return try await self.providersRepository().fetchRuleProviders()
                default:
                    return ProviderSummary(providers: [:])
                }
            } catch {
                appendLog(level: "error", message: onError(error))
                return ProviderSummary(providers: [:])
            }
        }

        let proxyProviders = await fetchProviderSummary(.proxyProviders) {
            tr("log.providers.fetch_proxy_failed", $0.localizedDescription)
        }
        let ruleProviders = await fetchProviderSummary(.ruleProviders) {
            tr("log.providers.fetch_rule_failed", $0.localizedDescription)
        }

        let proxyNames = proxyProviders.providers.keys.sorted()
        let ruleNames = ruleProviders.providers.keys.sorted()
        let total = proxyNames.count + ruleNames.count
        var done = 0
        var failed = 0
        func publishUpdatingProgress() {
            self.updateProviderRefreshStatus(
                ProviderRefreshStatusUpdate(
                    phase: .updating,
                    trigger: trigger,
                    progressDone: done,
                    progressTotal: total,
                    message: tr("app.provider_refresh.updating", done, total),
                    generation: generation))
        }

        publishUpdatingProgress()

        do {
            try await self.reloadProvidersConfigUseCase().execute(force: true)
            appendLog(level: "info", message: tr("log.providers.config_reload_success"))
        } catch {
            failed += 1
            appendLog(level: "error", message: tr("log.providers.config_reload_failed", error.localizedDescription))
        }

        guard checkpoint() else { return }

        let proxyResult = await self.updateProvidersSequential(
            names: proxyNames,
            operation: { name in
                try await self.updateProxyProviderUseCase().execute(name: name)
            },
            onError: { name, error in
                tr("log.providers.proxy_update_failed", name, error.localizedDescription)
            },
            shouldContinue: checkpoint,
            onStep: {
                done += 1
                publishUpdatingProgress()
            })
        failed += proxyResult.failed
        guard proxyResult.completed else { return }

        let ruleResult = await self.updateProvidersSequential(
            names: ruleNames,
            operation: { name in
                try await self.updateRuleProviderUseCase().execute(name: name)
            },
            onError: { name, error in
                tr("log.providers.rule_update_failed", name, error.localizedDescription)
            },
            shouldContinue: checkpoint,
            onStep: {
                done += 1
                publishUpdatingProgress()
            })
        failed += ruleResult.failed
        guard ruleResult.completed else { return }

        let resultPhase: ProviderRefreshPhase = failed == 0 ? .succeeded : .failed
        let resultMessage = failed == 0
            ? tr("app.provider_refresh.updated")
            : tr("app.provider_refresh.partial_failed", failed)
        self.updateProviderRefreshStatus(
            ProviderRefreshStatusUpdate(
                phase: resultPhase,
                trigger: trigger,
                progressDone: done,
                progressTotal: total,
                message: resultMessage,
                generation: generation))
        providerRefreshTask = nil
    }

    private func updateProviderRefreshStatus(_ update: ProviderRefreshStatusUpdate) {
        guard update.generation == providerRefreshGeneration else { return }
        providerRefreshStatus = ProviderRefreshStatus(
            phase: update.phase,
            trigger: update.trigger,
            progressDone: update.progressDone,
            progressTotal: update.progressTotal,
            message: update.message,
            updatedAt: Date())
    }

    func refreshProvidersAndRules() async {
        await runRefresh {
            let snapshot = try await self.fetchProvidersAndRulesUseCase().execute()
            let proxyProviders = snapshot.proxyProviders
            let ruleProviders = snapshot.ruleProviders
            let rules = snapshot.rules

            let filteredProxyProviders = proxyProviders.providers.filter { key, detail in
                self.shouldIncludeProxyProvider(named: key, detail: detail)
            }

            let previousProxyProviders = self.proxyProvidersDetail
            var nextProxyProviders: [String: ProviderDetail] = [:]
            nextProxyProviders.reserveCapacity(filteredProxyProviders.count)
            for (name, detail) in filteredProxyProviders {
                nextProxyProviders[name] = self.mergedProviderDetailPreservingNodes(
                    previous: previousProxyProviders[name],
                    incoming: detail)
            }

            self.proxyProvidersDetail = nextProxyProviders
            self.ruleProviders = ruleProviders.providers
            self.ruleItems = rules.rules

            self.providerProxyCount = filteredProxyProviders.count
            self.providerRuleCount = ruleProviders.providers.count
            self.rulesCount = rules.totalCount

            let currentNames = Set(filteredProxyProviders.keys)
            self.providerUpdating = self.providerUpdating.intersection(currentNames)
        }
    }

    private func updateProvidersSequential(
        names: [String],
        operation: (String) async throws -> Void,
        onError: (String, Error) -> String,
        shouldContinue: (() -> Bool)? = nil,
        onStep: (() -> Void)? = nil) async -> (completed: Bool, failed: Int)
    {
        var failed = 0
        for name in names {
            if let shouldContinue, !shouldContinue() {
                return (completed: false, failed: failed)
            }

            do {
                try await operation(name)
            } catch {
                failed += 1
                appendLog(level: "error", message: onError(name, error))
            }
            onStep?()
        }
        return (completed: true, failed: failed)
    }

    private func providerRefreshCancelReason(_ reason: String) -> String {
        switch reason {
        case "stop requested":
            tr("app.provider_refresh.reason.stop_requested")
        case "restart requested":
            tr("app.provider_refresh.reason.restart_requested")
        case "quit requested":
            tr("app.provider_refresh.reason.quit_requested")
        case "config switch requested":
            tr("app.provider_refresh.reason.config_switch_requested")
        case "superseded":
            tr("app.provider_refresh.reason.superseded")
        default:
            reason
        }
    }

    private func runSingleProviderUpdate(actionName: String, operation: @escaping () async throws -> Void) async {
        await runNoResponseAction(actionName) {
            try await operation()
            await self.refreshProvidersAndRules()
        }
    }
}
