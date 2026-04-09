import Foundation

@MainActor
extension AppViewModel {
    var buildPortPatchBodyUseCase: BuildPortPatchBodyUseCase {
        BuildPortPatchBodyUseCase()
    }

    var resolveOverlayPortFieldsUseCase: ResolveOverlayPortFieldsUseCase {
        ResolveOverlayPortFieldsUseCase()
    }

    enum EditableCoreSetting: String, CaseIterable, Identifiable {
        case allowLan = "allow-lan"
        case ipv6
        case tcpConcurrent = "tcp-concurrent"
        case logLevel = "log-level"

        var id: String {
            self.rawValue
        }

        var configKey: String {
            self.rawValue
        }
    }

    private func boolStateKeyPath(for setting: EditableCoreSetting) -> ReferenceWritableKeyPath<AppViewModel, Bool>? {
        switch setting {
        case .allowLan:
            \.settingsAllowLan
        case .ipv6:
            \.settingsIPv6
        case .tcpConcurrent:
            \.settingsTCPConcurrent
        case .logLevel:
            nil
        }
    }

    private func stringStateKeyPath(for setting: EditableCoreSetting)
    -> ReferenceWritableKeyPath<AppViewModel, String>? {
        switch setting {
        case .logLevel:
            \.settingsLogLevel
        case .allowLan, .ipv6, .tcpConcurrent:
            nil
        }
    }

    func boolValue(for setting: EditableCoreSetting) -> Bool {
        guard let keyPath = self.boolStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not store a Bool")
            return false
        }
        return self[keyPath: keyPath]
    }

    func stringValue(for setting: EditableCoreSetting) -> String {
        guard let keyPath = self.stringStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not store a String")
            return ""
        }
        return self[keyPath: keyPath]
    }

    func applyEditableCoreSetting(_ setting: EditableCoreSetting, to value: Bool) async {
        guard let keyPath = self.boolStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not accept Bool updates")
            return
        }
        await self.applyBooleanSetting(keyPath, configKey: setting.configKey, value: value)
    }

    func applyEditableCoreSetting(_ setting: EditableCoreSetting, to value: String) async {
        guard self.stringStateKeyPath(for: setting) != nil else {
            assertionFailure("Setting \(setting.configKey) does not accept String updates")
            return
        }

        let normalized = value.trimmed
        if setting == .logLevel, ConfigLogLevel(rawValue: normalized) == nil {
            settingsErrorMessage = tr("app.settings.error.invalid_log_level", value)
            settingsSavedMessage = nil
            return
        }

        await self.patchSingleConfig(setting.configKey, value: .string(normalized))
    }

    func applySettingTunMode(_ value: Bool) async {
        await toggleTunMode(value)
    }

    func applyProxyPorts(autoSaved: Bool = false) async {
        guard let body = self.validatedPortPatchBody(
            fields: self.proxyPortFields,
            errorMessageKey: "app.settings.error.port_range",
            skipEmptyValues: false)
        else { return }

        let syncingKey = autoSaved ? "ports-auto" : "ports"
        let successMessage = autoSaved ? tr("app.settings.saved.ports_auto") : tr("app.settings.saved.ports")
        await self.patchConfigBody(body, syncingKey: syncingKey, successMessage: successMessage)
    }

    func scheduleProxyPortsAutoSaveIfNeeded() {
        guard !suppressSettingsPersistence else { return }
        guard settingsSyncingKey == nil else { return }

        proxyPortsAutoSaveTask?.cancel()
        proxyPortsAutoSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 750_000_000)
            } catch {
                return
            }

            guard let self else { return }
            if Task.isCancelled { return }
            // Clear the tracking reference before saving so patchConfigBody()
            // will not cancel the currently running autosave task itself.
            self.proxyPortsAutoSaveTask = nil
            await self.applyProxyPorts(autoSaved: true)
        }
    }

    func cancelProxyPortsAutoSave() {
        proxyPortsAutoSaveTask?.cancel()
        proxyPortsAutoSaveTask = nil
    }

    func syncEditableSettings(from config: ConfigSnapshot) {
        let incoming = EditableSettingsSnapshot(config: config)

        if preserveLocalSettingsOnNextSync {
            preserveLocalSettingsOnNextSync = false
            lastSyncedEditableSettings = incoming
            persistEditableSettingsSnapshot()
            return
        }

        guard let previous = lastSyncedEditableSettings else {
            self.applyEditableSettingsSnapshotToUI(incoming)
            lastSyncedEditableSettings = incoming
            persistEditableSettingsSnapshot()
            return
        }

        suppressSettingsPersistence = true
        self.syncEditableFields(
            from: previous,
            to: incoming,
            fields: [
                (\.settingsAllowLan, \.allowLan),
                (\.settingsIPv6, \.ipv6),
                (\.settingsTCPConcurrent, \.tcpConcurrent),
                (\.isTunEnabled, \.tunEnabled),
            ])

        self.syncEditableFields(
            from: previous,
            to: incoming,
            fields: [
                (\.settingsLogLevel, \.logLevel),
                (\.settingsPort, \.port),
                (\.settingsSocksPort, \.socksPort),
                (\.settingsMixedPort, \.mixedPort),
                (\.settingsRedirPort, \.redirPort),
                (\.settingsTProxyPort, \.tproxyPort),
            ])
        suppressSettingsPersistence = false

        lastSyncedEditableSettings = incoming
        persistEditableSettingsSnapshot()
    }

    func currentEditableSettingsSnapshot() -> EditableSettingsSnapshot {
        EditableSettingsSnapshot(
            mode: currentMode,
            allowLan: settingsAllowLan,
            ipv6: settingsIPv6,
            tcpConcurrent: settingsTCPConcurrent,
            tunEnabled: isTunEnabled,
            logLevel: settingsLogLevel,
            port: settingsPort,
            socksPort: settingsSocksPort,
            mixedPort: settingsMixedPort,
            redirPort: settingsRedirPort,
            tproxyPort: settingsTProxyPort)
    }

    func applyPendingConfigSwitchSettingsOverlayIfNeeded() async {
        guard let overlay = pendingConfigSwitchOverlaySettings else { return }
        pendingConfigSwitchOverlaySettings = nil
        _ = await self.applyEditableSettingsOverlay(
            overlay,
            syncingKey: "config-switch-overlay",
            successMessage: tr("app.settings.overlay_success"))
    }

    func applyPendingAppLaunchSettingsOverlayIfNeeded(syncSystemProxyPort: Bool = true) async {
        guard let overlay = pendingAppLaunchOverlaySettings else { return }
        guard apiStatus == .healthy else { return }
        pendingAppLaunchOverlaySettings = nil
        _ = await self.applyEditableSettingsOverlay(
            overlay,
            syncingKey: "app-launch-overlay",
            successMessage: "",
            syncSystemProxyPort: syncSystemProxyPort)
    }

    func syncEditableSettingsOverlayForCoreBootstrap(
        _ overlay: EditableSettingsSnapshot,
        syncingKey: String) async
    {
        self.deferredEditableSettingsOverlay = (snapshot: overlay, syncingKey: syncingKey)

        if await self.applyDeferredEditableSettingsOverlayIfPossible() {
            self.deferredEditableSettingsOverlayTask?.cancel()
            self.deferredEditableSettingsOverlayTask = nil
            return
        }

        self.scheduleDeferredEditableSettingsOverlaySync()
    }

    func cancelDeferredEditableSettingsOverlaySync() {
        self.deferredEditableSettingsOverlayTask?.cancel()
        self.deferredEditableSettingsOverlayTask = nil
        self.deferredEditableSettingsOverlay = nil
    }

    @discardableResult
    func applyEditableSettingsOverlay(
        _ overlay: EditableSettingsSnapshot,
        syncingKey: String,
        successMessage: String,
        syncSystemProxyPort: Bool = true) async -> Bool
    {
        let fallback = lastSyncedEditableSettings
        let resolvedLogLevel = overlay.logLevel.trimmed.isEmpty
            ? (fallback?.logLevel ?? ConfigLogLevel.info.rawValue)
            : overlay.logLevel

        guard ConfigLogLevel(rawValue: resolvedLogLevel) != nil else {
            settingsErrorMessage = tr("app.settings.error.overlay_invalid_log_level", resolvedLogLevel)
            settingsSavedMessage = nil
            return false
        }

        let resolvedPortFields = self.resolveOverlayPortFieldsUseCase.execute(
            overlay: overlay,
            fallback: fallback)
        guard let portBody = validatedPortPatchBody(
            fields: resolvedPortFields,
            errorMessageKey: "app.settings.error.overlay_port_range",
            skipEmptyValues: true)
        else { return false }

        var body: [String: ConfigPatchValue] = [
            "mode": .string(overlay.mode.rawValue),
            "allow-lan": .bool(overlay.allowLan),
            "ipv6": .bool(overlay.ipv6),
            "tcp-concurrent": .bool(overlay.tcpConcurrent),
            "log-level": .string(resolvedLogLevel),
        ]
        let tunBody = await self.tunOverlayPatchBody(enabled: overlay.tunEnabled)
        body["tun"] = .object(tunBody)
        if overlay.tunEnabled {
            body["dns"] = .object(["enable": .bool(true)])
        }
        for (key, value) in portBody {
            body[key] = value
        }

        return await self.patchConfigBody(
            body,
            syncingKey: syncingKey,
            successMessage: successMessage,
            syncSystemProxyPort: syncSystemProxyPort)
    }
}
