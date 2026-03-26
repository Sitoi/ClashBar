import Foundation

@MainActor
extension AppSession {
    private var buildPortPatchBodyUseCase: BuildPortPatchBodyUseCase {
        BuildPortPatchBodyUseCase()
    }

    private var resolveOverlayPortFieldsUseCase: ResolveOverlayPortFieldsUseCase {
        ResolveOverlayPortFieldsUseCase()
    }

    private func fetchRuntimeConfigUseCase() throws -> FetchRuntimeConfigUseCase {
        try self.makeFetchRuntimeConfigUseCase(using: self.clientOrThrow())
    }

    private func patchRuntimeConfigUseCase() throws -> PatchRuntimeConfigUseCase {
        try self.makePatchRuntimeConfigUseCase(using: self.settingsPatchTransport())
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

    private func boolStateKeyPath(for setting: EditableCoreSetting) -> ReferenceWritableKeyPath<AppSession, Bool>? {
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

    private func stringStateKeyPath(for setting: EditableCoreSetting) -> ReferenceWritableKeyPath<AppSession, String>? {
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

    func effectiveMixedPort() -> Int {
        ResolveEffectiveMixedPortUseCase().execute(
            runtimeMixedPort: mixedPort,
            settingsMixedPort: settingsMixedPort)
    }

    func applyEditableSettingsSnapshotToUI(_ snapshot: EditableSettingsSnapshot) {
        suppressSettingsPersistence = true
        settingsAllowLan = snapshot.allowLan
        settingsIPv6 = snapshot.ipv6
        settingsTCPConcurrent = snapshot.tcpConcurrent
        isTunEnabled = snapshot.tunEnabled
        settingsLogLevel = snapshot.logLevel
        settingsPort = snapshot.port
        settingsSocksPort = snapshot.socksPort
        settingsMixedPort = snapshot.mixedPort
        settingsRedirPort = snapshot.redirPort
        settingsTProxyPort = snapshot.tproxyPort
        suppressSettingsPersistence = false
    }

    func applySettingBool(key: String, value: Bool) async {
        await self.patchSingleConfig(key, value: .bool(value))
    }

    func patchSingleConfig(_ key: String, value: ConfigPatchValue) async {
        _ = await self.patchConfigBody(
            [key: value],
            syncingKey: key,
            successMessage: tr("app.settings.saved.single_key", key))
    }

    @discardableResult
    func patchConfigBody(
        _ body: [String: ConfigPatchValue],
        syncingKey: String,
        successMessage: String,
        syncSystemProxyPort: Bool = true) async -> Bool
    {
        self.cancelProxyPortsAutoSave()
        settingsFeedbackClearTask?.cancel()
        settingsFeedbackClearTask = nil
        settingsSyncingKey = syncingKey
        settingsErrorMessage = nil
        settingsSavedMessage = nil
        defer { settingsSyncingKey = nil }
        let shouldSyncSystemProxyPort = syncSystemProxyPort && !self.isRemoteTarget && body.keys.contains { key in
            key == "mixed-port" || key == "port" || key == "socks-port"
        }
        let previousSystemProxyPorts =
            await previousSystemProxyPortsForSyncIfNeeded(shouldSync: shouldSyncSystemProxyPort)

        let patchKeysDescription = body.keys.sorted().joined(separator: ", ")
        do {
            ensureAPIClient()
            appendLog(level: "info", message: "PATCH /configs [\(patchKeysDescription)]")
            try await self.patchRuntimeConfigUseCase().execute(body: body.mapValues(\.jsonValue))
            appendLog(level: "info", message: "PATCH /configs succeeded [\(patchKeysDescription)]")
            await refreshFromAPI(includeSlowCalls: false)
            await self.reconcileEditableSettingsWithRuntimeConfig()
            settingsSavedMessage = successMessage
            self.scheduleSettingsFeedbackAutoClearIfNeeded(message: successMessage)
            await self.syncSystemProxyPortIfNeeded(
                shouldSync: shouldSyncSystemProxyPort,
                previousPorts: previousSystemProxyPorts)
            return true
        } catch {
            appendLog(
                level: "error",
                message: "PATCH /configs failed [\(patchKeysDescription)]: \(error.localizedDescription)")
            let message = tr("app.settings.error.save_failed", syncingKey, error.localizedDescription)
            if self.isOverlaySyncingKey(syncingKey) {
                appendLog(level: "error", message: message)
            } else {
                settingsErrorMessage = message
            }
            settingsSavedMessage = nil
            await refreshFromAPI(includeSlowCalls: false)
            await self.reconcileEditableSettingsWithRuntimeConfig()
            return false
        }
    }

    private func isOverlaySyncingKey(_ syncingKey: String) -> Bool {
        syncingKey.hasSuffix("-overlay")
    }

    private func scheduleDeferredEditableSettingsOverlaySync() {
        self.deferredEditableSettingsOverlayTask?.cancel()
        self.deferredEditableSettingsOverlayTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<120 {
                if Task.isCancelled { return }
                guard self.isRuntimeRunning else { return }
                if await self.applyDeferredEditableSettingsOverlayIfPossible() {
                    self.deferredEditableSettingsOverlayTask = nil
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                } catch {
                    return
                }
            }

            self.deferredEditableSettingsOverlayTask = nil
        }
    }

    private func applyDeferredEditableSettingsOverlayIfPossible() async -> Bool {
        guard let deferred = self.deferredEditableSettingsOverlay else { return true }
        guard await self.isCoreAPIReachableForOverlaySync() else { return false }

        let applied = await self.applyEditableSettingsOverlay(
            deferred.snapshot,
            syncingKey: deferred.syncingKey,
            successMessage: "")
        if applied {
            self.deferredEditableSettingsOverlay = nil
        }
        return applied
    }

    private func isCoreAPIReachableForOverlaySync() async -> Bool {
        do {
            let client = try self.clientOrThrow()
            let _: VersionInfo = try await self.makeFetchVersionUseCase(using: client).execute()
            return true
        } catch {
            return false
        }
    }

    func scheduleSettingsFeedbackAutoClearIfNeeded(message: String) {
        guard message.trimmedNonEmpty != nil else { return }

        settingsFeedbackClearTask?.cancel()
        settingsFeedbackClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard let self else { return }
            if self.settingsSavedMessage == message {
                self.settingsSavedMessage = nil
            }
        }
    }

    func clientOrThrow() throws -> MihomoAPIClient {
        if apiClient == nil {
            ensureAPIClient()
        }
        if let apiClient {
            return apiClient
        }
        throw APIError.invalidURL
    }

    func modeSwitchTransport() throws -> MihomoAPITransporting {
        try self.resolvedTransport(override: modeSwitchTransportOverride)
    }

    func settingsPatchTransport() throws -> MihomoAPITransporting {
        try self.resolvedTransport(override: settingsPatchTransportOverride)
    }

    private func previousSystemProxyPortsForSyncIfNeeded(shouldSync: Bool) async -> SystemProxyPorts? {
        guard shouldSync, isSystemProxyEnabled else { return nil }
        do {
            let config = try await self.fetchRuntimeConfigUseCase().execute()
            return systemProxyPorts(from: config)
        } catch {
            return currentSystemProxyPortsFromState()
        }
    }

    private func syncSystemProxyPortIfNeeded(shouldSync: Bool, previousPorts: SystemProxyPorts?) async {
        guard shouldSync, isSystemProxyEnabled else { return }

        do {
            let target = try await resolveSystemProxyTargetFromRuntimeConfig()
            try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
            systemProxyActiveDisplay = buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            appendLog(level: "info", message: tr("log.system_proxy.port_synced", target.ports.primaryPort ?? 0))

            if let previousPorts, previousPorts != target.ports {
                await closeAllConnections()
            }
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.port_sync_failed", systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
        }
    }

    private func applyBooleanSetting(
        _ keyPath: ReferenceWritableKeyPath<AppSession, Bool>,
        configKey: String,
        value: Bool) async
    {
        await self.applySettingBool(key: configKey, value: value)
    }

    private func reconcileEditableSettingsWithRuntimeConfig() async {
        do {
            let config = try await self.fetchRuntimeConfigSnapshot()
            let incoming = EditableSettingsSnapshot(config: config)
            self.applyEditableSettingsSnapshotToUI(incoming)
            self.lastSyncedEditableSettings = incoming
            self.persistEditableSettingsSnapshot()
        } catch {
            appendLog(level: "error", message: "Settings reconciliation failed: \(error.localizedDescription)")
        }
    }

    private var proxyPortFields: [SettingsPortField] {
        [
            SettingsPortField(key: "port", value: settingsPort),
            SettingsPortField(key: "socks-port", value: settingsSocksPort),
            SettingsPortField(key: "mixed-port", value: settingsMixedPort),
            SettingsPortField(key: "redir-port", value: settingsRedirPort),
            SettingsPortField(key: "tproxy-port", value: settingsTProxyPort),
        ]
    }

    private func tunOverlayPatchBody(enabled: Bool) async -> [String: ConfigPatchValue] {
        var tunBody: [String: ConfigPatchValue] = ["enable": .bool(enabled)]
        if enabled {
            let hasConfiguredStack = await self.selectedConfigDeclaresTunStack()
            if !hasConfiguredStack {
                tunBody["stack"] = .string("mixed")
            }
        }
        return tunBody
    }

    private func validatedPortPatchBody(
        fields: [SettingsPortField],
        errorMessageKey: String,
        skipEmptyValues: Bool) -> [String: ConfigPatchValue]?
    {
        do {
            return try self.buildPortPatchBodyUseCase.execute(fields: fields, skipEmptyValues: skipEmptyValues)
        } catch let BuildPortPatchBodyError.invalidPort(key) {
            settingsErrorMessage = tr(errorMessageKey, key)
            settingsSavedMessage = nil
            return nil
        } catch {
            settingsErrorMessage = tr(errorMessageKey, "unknown")
            settingsSavedMessage = nil
            return nil
        }
    }

    private func syncEditableFields<Value: Equatable>(
        from previous: EditableSettingsSnapshot,
        to incoming: EditableSettingsSnapshot,
        fields: [(ReferenceWritableKeyPath<AppSession, Value>, KeyPath<EditableSettingsSnapshot, Value>)])
    {
        for (stateKeyPath, snapshotKeyPath) in fields {
            guard self[keyPath: stateKeyPath] == previous[keyPath: snapshotKeyPath] else { continue }
            self[keyPath: stateKeyPath] = incoming[keyPath: snapshotKeyPath]
        }
    }

    private func resolvedTransport(override: MihomoAPITransporting?) throws -> MihomoAPITransporting {
        if let override {
            return override
        }
        return try self.clientOrThrow()
    }
}
