import AppKit
import Foundation

@MainActor
extension AppState {
    private struct CoreBootstrapOptions {
        let overlaySyncingKey: String
        let providerTrigger: ProviderRefreshTrigger
        let refreshProxyGroupsAfterBootstrap: Bool
        let refreshSystemProxyBeforeOverlay: Bool
        let refreshSystemProxyAfterBootstrap: Bool
    }

    func startCore(trigger: StartTrigger = .manual) async {
        guard !isCoreActionProcessing else { return }
        if trigger == .manual {
            shouldResumeCoreAfterNetworkRecovery = false
        }
        coreActionState = .starting
        defer { coreActionState = .idle }
        var settingsOverlay = currentEditableSettingsSnapshot()
        settingsOverlay = self.overlayApplyingPendingCoreFeatureRecovery(settingsOverlay)
        preserveLocalSettingsOnNextSync = true
        do {
            guard let configPath = await resolveSelectedConfigPath() else {
                let message = tr("log.start.no_config")
                appendLog(level: "error", message: message)
                if trigger == .auto {
                    startupErrorMessage = message
                    statusText = "Stopped"
                    apiStatus = .unknown
                }
                return
            }

            settingsOverlay = try await prepareTunOverlayForCoreStartup(
                configPath: configPath,
                overlay: settingsOverlay)

            let launchController = applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            statusText = "Starting"
            _ = try processManager.start(configPath: configPath, controller: launchController)

            await self.completeCoreBootstrap(
                configPath: configPath,
                settingsOverlay: settingsOverlay,
                options: CoreBootstrapOptions(
                    overlaySyncingKey: "start-overlay",
                    providerTrigger: .start,
                    refreshProxyGroupsAfterBootstrap: false,
                    refreshSystemProxyBeforeOverlay: true,
                    refreshSystemProxyAfterBootstrap: false))
        } catch {
            preserveLocalSettingsOnNextSync = false
            let message = tr("log.start.failed", error.localizedDescription)
            appendLog(level: "error", message: message)
            if trigger == .auto {
                statusText = "Stopped"
                apiStatus = .unknown
                startupErrorMessage = message
            } else {
                statusText = "Failed"
                apiStatus = .failed
            }
        }
    }

    func stopCore(trigger: StopTrigger = .manual) async {
        guard !isCoreActionProcessing else { return }
        if trigger == .manual {
            shouldResumeCoreAfterNetworkRecovery = false
        }
        coreActionState = .stopping
        defer { coreActionState = .idle }
        await self.prepareCoreFeatureRecoveryBeforeStop()
        cancelProviderRefresh(reason: "stop requested")
        processManager.stop()
        cancelPolling()
        statusText = "Stopped"
        apiStatus = .unknown
        resetTrafficPresentation()
    }

    func restartCore(trigger: ProviderRefreshTrigger = .restart) async {
        guard !isCoreActionProcessing else { return }
        coreActionState = .restarting
        defer { coreActionState = .idle }
        let settingsOverlay = self.overlayApplyingPendingCoreFeatureRecovery(currentEditableSettingsSnapshot())
        preserveLocalSettingsOnNextSync = true
        cancelProviderRefresh(reason: "restart requested")
        do {
            guard let configPath = await resolveSelectedConfigPath() else {
                appendLog(level: "error", message: tr("log.start.no_config"))
                return
            }

            let launchController = applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            _ = try processManager.restart(configPath: configPath, controller: launchController)
            await self.completeCoreBootstrap(
                configPath: configPath,
                settingsOverlay: settingsOverlay,
                options: CoreBootstrapOptions(
                    overlaySyncingKey: "restart-overlay",
                    providerTrigger: trigger,
                    refreshProxyGroupsAfterBootstrap: true,
                    refreshSystemProxyBeforeOverlay: false,
                    refreshSystemProxyAfterBootstrap: true))
        } catch {
            preserveLocalSettingsOnNextSync = false
            appendLog(level: "error", message: tr("log.restart.failed", error.localizedDescription))
        }
    }

    func performPrimaryCoreAction() async {
        guard !isCoreActionProcessing else { return }
        if isRuntimeRunning {
            await self.restartCore()
        } else {
            await self.startCore(trigger: .manual)
        }
    }

    func setUILanguage(_ language: AppLanguage) {
        guard uiLanguage != language else { return }
        uiLanguage = language
        defaults.set(language.rawValue, forKey: uiLanguageKey)
    }

    func setAppearanceMode(_ mode: AppAppearanceMode) {
        guard appearanceMode != mode else { return }
        appearanceMode = mode
        defaults.set(mode.rawValue, forKey: appearanceModeKey)
        self.applyAppAppearance()
    }

    func quitApp() async {
        self.shutdownForTermination()
        NSApplication.shared.terminate(nil)
    }

    func shutdownForTermination() {
        shouldResumeCoreAfterNetworkRecovery = false
        stopNetworkReachabilityMonitoring(resetState: true)
        cancelProviderRefresh(reason: "quit requested")
        cancelPolling()
        if processManager.isRunning {
            processManager.stop()
        }
    }

    func applyAppAppearance() {
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func normalizeMode(_ raw: String?) -> CoreMode? {
        guard let raw else { return nil }
        return CoreMode(rawValue: raw.lowercased())
    }

    func restartCoreIfNeededForConfigSwitch(previousPath: String?, nextPath: String?) async {
        guard let nextPath else { return }
        guard previousPath != nextPath else { return }
        guard processManager.isRunning else { return }

        pendingConfigSwitchOverlaySettings = currentEditableSettingsSnapshot()
        preserveLocalSettingsOnNextSync = true
        proxyGroups = []
        groupLatencies = [:]
        groupLatencyLoading = []
        appendLog(level: "info", message: tr("log.config.changed_restart"))
        cancelProviderRefresh(reason: "config switch requested")
        await self.restartCore(trigger: .configSwitch)
        await applyPendingConfigSwitchSettingsOverlayIfNeeded()
    }

    func refreshProxyGroupsAfterRestart() async {
        for _ in 0..<8 {
            await refreshProxyGroups()
            if apiStatus == .healthy { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    func attemptAutoStartIfNeeded() async {
        if didAttemptAutoStart { return }
        didAttemptAutoStart = true
        await self.startCore(trigger: .auto)
    }

    private func completeCoreBootstrap(
        configPath: String,
        settingsOverlay: EditableSettingsSnapshot,
        options: CoreBootstrapOptions) async
    {
        statusText = "Running"
        apiStatus = .healthy
        resetTrafficPresentation()
        ensureAPIClient()
        startPolling()
        await refreshFromAPI(includeSlowCalls: true)

        await applyEditableSettingsOverlay(
            settingsOverlay,
            syncingKey: options.overlaySyncingKey,
            successMessage: "")
        await validateTunPermissionsOnStartup()
        enqueueProviderRefresh(trigger: options.providerTrigger)

        if options.refreshProxyGroupsAfterBootstrap {
            await self.refreshProxyGroupsAfterRestart()
        }

        // Keep startup responsive even when helper registration or system proxy reads are slow.
        scheduleSystemProxyStartupPostflight(
            refreshStatusBeforeOverlay: options.refreshSystemProxyBeforeOverlay,
            refreshStatusAfterBootstrap: options.refreshSystemProxyAfterBootstrap)

        defaults.set(configPath, forKey: lastSuccessfulConfigPathKey)
        startupErrorMessage = nil
        await self.restoreCoreFeaturesAfterStartupIfNeeded(startedWithTunEnabled: settingsOverlay.tunEnabled)
        enforceNetworkManagedCorePolicyIfNeeded()
    }

    private func overlayApplyingPendingCoreFeatureRecovery(_ overlay: EditableSettingsSnapshot)
        -> EditableSettingsSnapshot
    {
        guard let recovery = self.pendingCoreFeatureRecoveryState else { return overlay }
        guard recovery.tunEnabled else { return overlay }
        return overlay.withTunEnabled(true)
    }

    private func prepareCoreFeatureRecoveryBeforeStop() async {
        let runtimeRunningBeforeStop = self.isRuntimeRunning
        let recovery = CoreFeatureRecoveryState(
            systemProxyEnabled: runtimeRunningBeforeStop && self.isSystemProxyEnabled,
            tunEnabled: runtimeRunningBeforeStop && self.isTunEnabled)

        self.pendingCoreFeatureRecoveryState = recovery.shouldRecoverAnyFeature ? recovery : nil

        if runtimeRunningBeforeStop, recovery.tunEnabled {
            self.isTunEnabled = false
            self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.disabled")))
        }

        guard self.isSystemProxyEnabled else { return }
        self.isProxySyncing = true
        defer { self.isProxySyncing = false }

        do {
            try await self.applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
            self.isSystemProxyEnabled = false
            self.appendLog(
                level: "info",
                message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.disabled")))
        } catch {
            self.appendLog(
                level: "error",
                message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
            await self.refreshSystemProxyStatus()
        }
    }

    private func restoreCoreFeaturesAfterStartupIfNeeded(startedWithTunEnabled: Bool) async {
        guard let recovery = self.pendingCoreFeatureRecoveryState else { return }
        guard recovery.shouldRecoverAnyFeature else {
            self.pendingCoreFeatureRecoveryState = nil
            return
        }
        guard self.isRuntimeRunning else { return }

        if self.autoManageCoreOnNetworkChangeEnabled, self.networkReachabilityStatus == .offline {
            return
        }

        var remainingSystemProxyRecovery = recovery.systemProxyEnabled
        var remainingTunRecovery = recovery.tunEnabled

        if recovery.tunEnabled, startedWithTunEnabled {
            if !self.isTunEnabled {
                self.isTunEnabled = true
            }
            remainingTunRecovery = false
            self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.enabled")))
        }

        if recovery.systemProxyEnabled {
            self.isProxySyncing = true
            defer { self.isProxySyncing = false }

            do {
                let target = try await self.resolveSystemProxyTargetFromRuntimeConfig()
                try await self.applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                self.isSystemProxyEnabled = true
                remainingSystemProxyRecovery = false
                self.appendLog(
                    level: "info",
                    message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.enabled")))
            } catch {
                self.appendLog(
                    level: "error",
                    message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
                await self.refreshSystemProxyStatus()
            }
        }

        let remaining = CoreFeatureRecoveryState(
            systemProxyEnabled: remainingSystemProxyRecovery,
            tunEnabled: remainingTunRecovery)
        self.pendingCoreFeatureRecoveryState = remaining.shouldRecoverAnyFeature ? remaining : nil
    }
}
