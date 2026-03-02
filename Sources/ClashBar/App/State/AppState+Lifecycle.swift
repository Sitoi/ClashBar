import AppKit
import Foundation

@MainActor
extension AppState {
    func startCore(trigger: StartTrigger = .manual) async {
        guard !isCoreActionProcessing else { return }
        coreActionState = .starting
        defer { coreActionState = .idle }
        var settingsOverlay = currentEditableSettingsSnapshot()
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
                overlay: settingsOverlay
            )

            let launchController = applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            statusText = "Starting"
            _ = try processManager.start(configPath: configPath, controller: launchController)

            await completeCoreBootstrap(
                configPath: configPath,
                settingsOverlay,
                overlaySyncingKey: "start-overlay",
                providerTrigger: .start,
                refreshProxyGroupsAfterBootstrap: false,
                refreshSystemProxyBeforeOverlay: true,
                refreshSystemProxyAfterBootstrap: false
            )
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

    func stopCore() async {
        guard !isCoreActionProcessing else { return }
        coreActionState = .stopping
        defer { coreActionState = .idle }
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
        let settingsOverlay = currentEditableSettingsSnapshot()
        preserveLocalSettingsOnNextSync = true
        cancelProviderRefresh(reason: "restart requested")
        do {
            guard let configPath = await resolveSelectedConfigPath() else {
                appendLog(level: "error", message: tr("log.start.no_config"))
                return
            }

            let launchController = applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            _ = try processManager.restart(configPath: configPath, controller: launchController)
            await completeCoreBootstrap(
                configPath: configPath,
                settingsOverlay,
                overlaySyncingKey: "restart-overlay",
                providerTrigger: trigger,
                refreshProxyGroupsAfterBootstrap: true,
                refreshSystemProxyBeforeOverlay: false,
                refreshSystemProxyAfterBootstrap: true
            )
        } catch {
            preserveLocalSettingsOnNextSync = false
            appendLog(level: "error", message: tr("log.restart.failed", error.localizedDescription))
        }
    }

    func performPrimaryCoreAction() async {
        guard !isCoreActionProcessing else { return }
        if isRuntimeRunning {
            await restartCore()
        } else {
            await startCore(trigger: .manual)
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
        applyAppAppearance()
    }

    func quitApp() async {
        shutdownForTermination()
        NSApplication.shared.terminate(nil)
    }

    func shutdownForTermination() {
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
        await restartCore(trigger: .configSwitch)
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
        await startCore(trigger: .auto)
    }

    func completeCoreBootstrap(
        configPath: String,
        _ settingsOverlay: EditableSettingsSnapshot,
        overlaySyncingKey: String,
        providerTrigger: ProviderRefreshTrigger,
        refreshProxyGroupsAfterBootstrap: Bool,
        refreshSystemProxyBeforeOverlay: Bool,
        refreshSystemProxyAfterBootstrap: Bool
    ) async {
        statusText = "Running"
        apiStatus = .healthy
        resetTrafficPresentation()
        ensureAPIClient()
        startPolling()
        await refreshFromAPI(includeSlowCalls: true)

        if refreshSystemProxyBeforeOverlay {
            await refreshSystemProxyStatus()
        }

        await applyEditableSettingsOverlay(
            settingsOverlay,
            syncingKey: overlaySyncingKey,
            successMessage: ""
        )
        await validateTunPermissionsOnStartup()
        await ensureSystemProxyConsistencyOnFirstLaunchIfNeeded()
        enqueueProviderRefresh(trigger: providerTrigger)

        if refreshProxyGroupsAfterBootstrap {
            await refreshProxyGroupsAfterRestart()
        }
        if refreshSystemProxyAfterBootstrap {
            await refreshSystemProxyStatus()
        }

        defaults.set(configPath, forKey: lastSuccessfulConfigPathKey)
        startupErrorMessage = nil
    }

}
