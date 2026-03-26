import Foundation

@MainActor
extension AppSession {
    func switchToMachineTarget(_ target: MachineTarget) async {
        self.remoteMachineStore.selectTarget(target)

        self.cancelPolling()
        self.resetTrafficPresentation()
        self.clearAllLogs()
        self.proxyGroups = []
        self.ruleItems = []
        self.connectionsStore.connections = []
        self.connectionsStore.connectionsCount = 0

        switch target {
        case .local:
            self.appendLog(level: "info", message: self.tr("log.remote.switched_to_local"))
            if let configPath = await self.resolveSelectedConfigPath() {
                self.applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            } else {
                let fallback = "127.0.0.1:9090"
                self.controller = fallback
                self.controllerSecret = nil
                self.externalControllerDisplay = fallback
                self.controllerUIURL = self.makeControllerUIURL(fallback)
                self.ensureAPIClient()
            }

            if let snapshot = self.loadPersistedEditableSettingsSnapshot() {
                self.applyEditableSettingsSnapshotToUI(snapshot)
                self.preserveLocalSettingsOnNextSync = true
                self.pendingAppLaunchOverlaySettings = snapshot
            }
            self.lastSyncedEditableSettings = nil

        case let .remote(machine):
            self.appendLog(
                level: "info",
                message: self.tr("log.remote.switched_to_remote", machine.name, machine.displayAddress))
            self.controller = machine.controllerAddress
            self.controllerSecret = machine.secret
            self.externalControllerDisplay = machine.displayAddress
            self.controllerUIURL = self.makeControllerUIURL(machine.controllerAddress)
            self.ensureAPIClient()
            self.lastSyncedEditableSettings = nil
            self.preserveLocalSettingsOnNextSync = false
            self.remoteMachineStore.checkConnectivity(for: machine)
        }

        await self.refreshFromAPI(includeSlowCalls: true)

        if self.lastSyncedEditableSettings == nil {
            _ = try? await self.fetchRuntimeConfigSnapshot()
        }

        if case .local = target {
            await self.applyPendingAppLaunchSettingsOverlayIfNeeded()
        }

        if self.apiStatus == .healthy || self.apiStatus == .degraded {
            self.startPolling()
        }
    }
}
