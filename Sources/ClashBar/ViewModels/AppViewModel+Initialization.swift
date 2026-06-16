import Foundation

@MainActor
extension AppViewModel {
    func configureManagedProcessCallbacks() {
        self.mihomoBinaryPath = self.coreRepository.detectedBinaryPath ?? "-"
        if let managedProcess = self.processManager as? MihomoProcessManager {
            managedProcess.onLog = { [weak self] line in
                Task { @MainActor in
                    guard self?.isRemoteTarget != true else { return }
                    self?.appendMihomoLog(level: "info", message: line)
                }
            }
            managedProcess.onTermination = { [weak self] code in
                Task { @MainActor in
                    guard self?.isRemoteTarget != true else { return }
                    let message = self?.tr("log.process.terminated", code) ?? ""
                    self?.statusText = "Failed"
                    self?.apiStatus = .failed
                    self?.resetTrafficPresentation()
                    self?.appendLog(level: "error", message: message)
                    self?.cancelPolling()
                    if self?.coreActionState == .idle, let self, !message.isEmpty {
                        self.presentCoreFailureAlert(
                            title: self.tr("app.core.alert.process_terminated.title"),
                            message: message,
                            dedupeKey: "core-process-terminated",
                            style: .critical)
                    }
                }
            }
        }
    }

    func bootstrapDirectoriesAndLogs() {
        do {
            try self.workingDirectoryManager.bootstrapDirectories()
            clashbarLogFileURL = self.workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "clashbar.log",
                isDirectory: false)
            mihomoLogFileURL = self.workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "mihomo.log",
                isDirectory: false)

            if let clashbarLogFileURL, self.clashbarLogStore == nil {
                self.clashbarLogStore = AppLogStore(logFileURL: clashbarLogFileURL)
            }
            if let mihomoLogFileURL, self.mihomoLogStore == nil {
                self.mihomoLogStore = AppLogStore(logFileURL: mihomoLogFileURL)
            }
            ensureLogFileExists()
            seedBundledConfigIfNeeded()
        } catch {
            appendLog(level: "error", message: tr("log.working_dir_init_failed", error.localizedDescription))
        }
    }

    func performDeferredInitialization(startBackgroundRefresh: Bool) {
        restoreSavedConfigDirectory()
        restoreLastSuccessfulConfigIfAvailable()
        self.remoteConfigSubscriptions = loadPersistedRemoteConfigSubscriptions()
        pruneRemoteConfigSubscriptionsIfNeeded()
        restartRemoteConfigBackgroundTasksIfNeeded()
        self.ssidStrategyRules = loadPersistedSSIDStrategyRules()
        self.pruneSSIDStrategyRulesIfNeeded()
        self.remoteMachineStore.resetActiveTarget()
        if let configPath = self.configRepository.selectedConfig?.path {
            _ = self.applyExternalControllerFromSelectedConfigFile(configPath: configPath)
        } else {
            self.refreshControllerUIURL()
        }
        if let persisted = loadPersistedEditableSettingsSnapshot() {
            applyEditableSettingsSnapshotToUI(persisted)
            self.preserveLocalSettingsOnNextSync = true
            self.pendingAppLaunchOverlaySettings = persisted
        }
        let persistedSystemProxyExceptions = loadPersistedSystemProxyExceptions() ?? Self.defaultSystemProxyExceptions
        self.replaceSystemProxyExceptionsDraft(with: persistedSystemProxyExceptions)
        self.lastSavedSystemProxyExceptions = self.normalizedSystemProxyExceptionValues(persistedSystemProxyExceptions)

        if startBackgroundRefresh {
            Task { [weak self] in
                guard let self else { return }
                await self.refreshFromAPI(includeSlowCalls: true)
                await self.applyPendingAppLaunchSettingsOverlayIfNeeded()
                self.seedCoreFeatureRecoveryFromPersistedQuitState()
                if self.hasSystemProxyOpenIntent {
                    await self.systemProxyRepository.warmUpHelperIfPossible()
                    await self.refreshSystemProxyHelperStatus()
                    await self.refreshSystemProxyStatus()
                    await self.ensureSystemProxyConsistencyOnFirstLaunchIfNeeded()
                } else {
                    self.resetSystemProxyObservedState()
                    self.didCheckSystemProxyConsistencyOnLaunch = true
                }
            }

            self.startConfigDirectoryMonitoringIfNeeded()
        }
        if startBackgroundRefresh, self.autoStartCore {
            if !self.shouldDeferAutoStartForMissingManagedCore() {
                Task { [weak self] in
                    await self?.attemptAutoStartIfNeeded()
                }
            }
        }

        self.refreshSSIDStrategyState(requestAuthorizationIfNeeded: self.ssidStrategyEnabled)
        self.updateNetworkReachabilityMonitoringState()
        self.refreshMenuBarDisplaySnapshotIfNeeded()
    }
}

extension AppViewModel {
    static func resolveBundledMihomoCoreFlag() -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ClashBarBundlesMihomoCore") else {
            return true
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return NSString(string: string).boolValue
        }
        return true
    }

    func hasInstalledManagedMihomoCore() -> Bool {
        FileManager.default.fileExists(atPath: workingDirectoryManager.managedMihomoBinaryURL.path)
    }

    func shouldDeferAutoStartForMissingManagedCore() -> Bool {
        !bundlesMihomoCore && !self.hasInstalledManagedMihomoCore()
    }

    func coreErrorMessage(_ error: Error) -> String {
        if let binaryResolutionError = error as? MihomoBinaryResolutionError {
            switch binaryResolutionError {
            case let .binaryNotFound(expectedDirectory):
                return tr("app.core.error.binary_not_found", expectedDirectory)
            }
        }

        return error.localizedDescription
    }
}
