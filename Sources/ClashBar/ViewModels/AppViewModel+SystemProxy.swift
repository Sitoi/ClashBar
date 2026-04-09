import Foundation

@MainActor
extension AppViewModel {
    static let defaultSystemProxyExceptions: [String] = [
        "::1",
        "*.local",
        "<local>",
        "localhost",
        "127.0.0.1",
        "192.168.0.0/16",
        "10.0.0.0/8",
        "172.16.0.0/12",
    ]

    var hasPendingSystemProxyExceptionsChanges: Bool {
        self.currentSystemProxyExceptionValues() != self.lastSavedSystemProxyExceptions
    }

    var canAddSystemProxyException: Bool {
        self.systemProxyNewException.trimmedNonEmpty != nil
    }

    func addSystemProxyExceptionDraft() {
        guard let value = self.systemProxyNewException.trimmedNonEmpty else { return }
        let existing = Set(self.currentSystemProxyExceptionValues().map { $0.lowercased() })
        guard !existing.contains(value.lowercased()) else {
            self.systemProxyNewException = ""
            return
        }

        self.systemProxyExceptions.append(EditableSystemProxyException(value: value))
        self.systemProxyNewException = ""
    }

    func removeSystemProxyExceptionDraft(id: EditableSystemProxyException.ID) {
        self.systemProxyExceptions.removeAll { $0.id == id }
    }

    func replaceSystemProxyExceptionsDraft(with values: [String]) {
        self.systemProxyExceptions = self.systemProxyExceptionRows(from: values)
        self.systemProxyNewException = ""
    }

    func restoreDefaultSystemProxyExceptionsDraft() {
        self.replaceSystemProxyExceptionsDraft(with: Self.defaultSystemProxyExceptions)
    }

    func saveSystemProxyExceptions() async {
        let normalized = self.currentSystemProxyExceptionValues()
        self.replaceSystemProxyExceptionsDraft(with: normalized)

        let success = await self.runSystemProxySettingsOperation(
            syncingKey: "system-proxy-exceptions",
            successMessage: tr("app.settings.saved.system_proxy_exceptions"))
        {
            try await self.systemProxyRepository.setExceptionsList(normalized)
        }

        guard success else { return }
        self.lastSavedSystemProxyExceptions = normalized
        self.persistSystemProxyExceptions()
    }

    func refreshSystemProxyExceptionsFromSystemIfPossible(overwriteEmpty: Bool = false) async {
        guard !self.hasPendingSystemProxyExceptionsChanges else { return }

        do {
            let values = try await self.systemProxyRepository.readExceptionsList()
            let normalized = self.normalizedSystemProxyExceptionValues(values)
            guard overwriteEmpty || !normalized.isEmpty else { return }
            self.replaceSystemProxyExceptionsDraft(with: normalized)
            self.lastSavedSystemProxyExceptions = normalized
            self.persistSystemProxyExceptions()
        } catch {
            return
        }
    }

    func applyCurrentSystemProxyExceptionsIfNeeded() async throws {
        try await self.systemProxyRepository.setExceptionsList(self.currentSystemProxyExceptionValues())
    }

    var isSystemProxyUsingRemoteCore: Bool {
        guard self.isSystemProxyEnabled,
              let activeDisplay = self.systemProxyActiveDisplay?.trimmedNonEmpty,
              let activeHost = self.controllerHost(from: activeDisplay)?.trimmedNonEmpty
        else {
            return false
        }

        let localHost = self.controllerHost(from: self.localExternalControllerDisplay)?.trimmedNonEmpty ?? "127.0.0.1"
        return self.normalizedSystemProxyComparisonHost(activeHost) != self
            .normalizedSystemProxyComparisonHost(localHost)
    }

    func clearSystemProxyOpenFailureHint() {
        self.systemProxyOpenFailureHint = nil
    }

    func updateSystemProxyOpenFailureHint(for error: Error) {
        self.systemProxyOpenFailureHint = self.systemProxyFailureHintMessage(for: error)
    }

    func updateSystemProxyOpenFailureHint(for reason: SystemProxyHelperFailureReason) {
        self.systemProxyOpenFailureHint = self.systemProxyFailureReasonMessage(for: reason)
    }

    var hasSystemProxyOpenIntent: Bool {
        self.isSystemProxyEnabled
            || self.systemProxyEnableIntentInFlight
            || (self.pendingCoreFeatureRecoveryState?.systemProxyEnabled ?? false)
            || self.defaults.bool(forKey: self.systemProxyEnabledOnQuitKey)
    }

    func resetSystemProxyObservedState() {
        self.systemProxyBackgroundActivityAllowed = nil
        self.systemProxyHelperProcessRunning = nil
        self.systemProxyHelperFailureReason = nil
        self.systemProxyHelperFailureMessage = nil
        if !self.isSystemProxyEnabled {
            self.systemProxyActiveDisplay = nil
        }
    }

    private func applyHelperHealthSnapshot(_ snapshot: SystemProxyHelperHealthSnapshot) {
        let previousReason = self.systemProxyHelperFailureReason
        let previousMessage = self.systemProxyHelperFailureMessage

        self.systemProxyBackgroundActivityAllowed = snapshot.backgroundActivityAllowed
        self.systemProxyHelperProcessRunning = snapshot.processRunning
        self.systemProxyHelperFailureReason = snapshot.failureReason
        self.systemProxyHelperFailureMessage = snapshot.rawMessage

        guard let failureReason = snapshot.failureReason else { return }

        if snapshot.rawMessage != previousMessage || failureReason != previousReason {
            let message = snapshot.rawMessage ?? self.systemProxyFailureReasonMessage(for: failureReason)
            appendLog(level: "error", message: tr("log.system_proxy.helper_failed", message))
        }

        if self.hasSystemProxyOpenIntent || self.systemProxyEnableIntentInFlight {
            self.updateSystemProxyOpenFailureHint(for: failureReason)
        }
    }

    func applySystemProxy(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try await self.systemProxyRepository.apply(enabled: enabled, host: host, ports: ports)
    }

    func readSystemProxyEnabledState() async throws -> Bool {
        try await self.systemProxyRepository.isEnabled()
    }

    func readSystemProxyActiveDisplay() async throws -> String? {
        try await self.systemProxyRepository.readActiveDisplay()
    }

    func readSystemProxyExceptions() async throws -> [String] {
        try await self.systemProxyRepository.readExceptionsList()
    }

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await self.systemProxyRepository.isConfigured(host: host, ports: ports)
    }

    func refreshSystemProxyHelperStatus() async {
        guard self.hasSystemProxyOpenIntent else {
            self.resetSystemProxyObservedState()
            return
        }
        let snapshot = await self.systemProxyRepository.readHelperHealthSnapshot()
        self.applyHelperHealthSnapshot(snapshot)
    }

    func refreshSystemProxyHelperRuntimeSnapshot() async {
        await self.refreshSystemProxyHelperStatus()
    }

    func handleApplicationDidBecomeActive() {
        self.refreshLaunchAtLoginStatus()
        guard !self.isRemoteTarget, self.hasSystemProxyOpenIntent else { return }

        Task { [weak self] in
            guard let self else { return }

            let previousHealth = await self.systemProxyRepository.readHelperHealthSnapshot()
            await self.systemProxyRepository.warmUpHelperIfPossible()
            await self.refreshSystemProxyHelperStatus()

            let shouldRefreshProxyStatus = self.isSystemProxyEnabled
                || previousHealth.registrationState == .requiresApproval
                || previousHealth.failureReason == .backgroundActivityDisabled
                || previousHealth.failureReason == .helperNotRegistered

            if shouldRefreshProxyStatus {
                await self.refreshSystemProxyStatus()
            }
        }
    }

    func systemProxyPorts(from config: ConfigSnapshot) -> SystemProxyPorts {
        ResolveSystemProxyPortsUseCase().execute(
            mixedPort: config.mixedPort,
            httpPort: config.port,
            socksPort: config.socksPort)
    }

    func currentSystemProxyPortsFromState() -> SystemProxyPorts {
        ResolveSystemProxyPortsUseCase().execute(
            mixedPort: mixedPort,
            httpPort: port,
            socksPort: socksPort)
    }

    func resolveSystemProxyTargetFromRuntimeConfig() async throws -> (host: String, ports: SystemProxyPorts) {
        let config = try await fetchRuntimeConfigSnapshot()
        let ports = self.systemProxyPorts(from: config)
        guard ports.hasEnabledPort else {
            throw SystemProxyServiceError.invalidPort
        }
        return (host: controllerHost(), ports: ports)
    }

    func ensureSystemProxyConsistencyOnFirstLaunchIfNeeded() async {
        guard !didCheckSystemProxyConsistencyOnLaunch else { return }
        guard isRuntimeRunning else { return }
        guard self.hasSystemProxyOpenIntent else {
            self.resetSystemProxyObservedState()
            didCheckSystemProxyConsistencyOnLaunch = true
            return
        }
        guard isSystemProxyEnabled else {
            didCheckSystemProxyConsistencyOnLaunch = true
            return
        }

        do {
            let target = try await resolveSystemProxyTargetFromRuntimeConfig()
            let isConfigured = try await isSystemProxyConfigured(host: target.host, ports: target.ports)
            if !isConfigured {
                try await self.applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                appendLog(
                    level: "info",
                    message: tr("log.system_proxy.startup_repaired", target.host, target.ports.primaryPort ?? 0))
            }
            try await self.applyCurrentSystemProxyExceptionsIfNeeded()
            self.clearSystemProxyOpenFailureHint()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
            systemProxyActiveDisplay = buildSystemProxyDisplayString(host: target.host, ports: target.ports)

            didCheckSystemProxyConsistencyOnLaunch = true
            await refreshSystemProxyStatus()
        } catch {
            appendLog(
                level: "error",
                message: tr("log.system_proxy.startup_repair_failed", self.systemProxyErrorMessage(error)))
            self.updateSystemProxyOpenFailureHint(for: error)
            await self.refreshSystemProxyHelperStatus()
        }
    }

    func scheduleSystemProxyStartupPostflight(
        refreshStatusBeforeOverlay: Bool,
        refreshStatusAfterBootstrap: Bool)
    {
        guard self.hasSystemProxyOpenIntent else {
            self.resetSystemProxyObservedState()
            return
        }
        let shouldRefreshStatus = refreshStatusBeforeOverlay || refreshStatusAfterBootstrap
        let shouldRepairConsistency = !didCheckSystemProxyConsistencyOnLaunch
        guard shouldRefreshStatus || shouldRepairConsistency else { return }

        Task { [weak self] in
            guard let self else { return }

            if shouldRefreshStatus {
                await self.refreshSystemProxyStatus()
            }

            if shouldRepairConsistency {
                await self.ensureSystemProxyConsistencyOnFirstLaunchIfNeeded()
                if shouldRefreshStatus {
                    await self.refreshSystemProxyStatus()
                }
            }
        }
    }

    func systemProxyErrorMessage(_ error: Error) -> String {
        guard let serviceError = error as? SystemProxyServiceError else {
            return error.localizedDescription
        }

        switch serviceError {
        case .invalidHost:
            return tr("app.system_proxy.error.invalid_host")
        case .invalidPort:
            return tr("app.system_proxy.error.invalid_port")
        case .helperNotBundled:
            return tr("app.system_proxy.error.helper_not_bundled")
        case .helperRequiresInstallToApplications:
            return tr("app.system_proxy.error.helper_install_location")
        case .helperNeedsApproval:
            return tr("app.system_proxy.error.helper_needs_approval")
        case let .helperNotRegistered(message):
            if let message, !message.isEmpty {
                return tr("app.system_proxy.error.helper_not_registered_with_detail", message)
            }
            return tr("app.system_proxy.error.helper_not_registered")
        case .helperStartTimedOut:
            return tr("app.system_proxy.error.helper_start_timed_out")
        case let .helperInvalidSignature(message):
            return tr("app.system_proxy.error.helper_invalid_signature", message)
        case let .helperConnectionFailed(message):
            return tr("app.system_proxy.error.helper_connection_failed", message)
        case let .helperOperationFailed(message):
            return tr("app.system_proxy.error.helper_operation_failed", message)
        }
    }

    func systemProxyFailureHintMessage(for error: Error) -> String {
        guard let serviceError = error as? SystemProxyServiceError else {
            return tr("app.system_proxy.alert.unknown")
        }

        switch serviceError {
        case .invalidHost:
            return tr("app.system_proxy.alert.invalid_host")
        case .invalidPort:
            return tr("app.system_proxy.alert.invalid_port")
        case .helperNotBundled:
            return tr("app.system_proxy.alert.helper_not_bundled")
        case .helperRequiresInstallToApplications:
            return tr("app.system_proxy.alert.helper_install_location")
        case .helperNeedsApproval:
            return tr("app.system_proxy.alert.background_activity_disabled")
        case .helperNotRegistered:
            return tr("app.system_proxy.alert.helper_not_registered")
        case .helperStartTimedOut:
            return tr("app.system_proxy.alert.helper_start_timed_out")
        case .helperInvalidSignature:
            return tr("app.system_proxy.alert.helper_invalid_signature")
        case .helperConnectionFailed:
            return tr("app.system_proxy.alert.helper_connection_failed")
        case .helperOperationFailed:
            return tr("app.system_proxy.alert.helper_operation_failed")
        }
    }

    private func systemProxyFailureReasonMessage(for reason: SystemProxyHelperFailureReason) -> String {
        switch reason {
        case .backgroundActivityDisabled:
            tr("app.system_proxy.alert.background_activity_disabled")
        case .helperNotRegistered:
            tr("app.system_proxy.alert.helper_not_registered")
        case .helperStartTimedOut:
            tr("app.system_proxy.alert.helper_start_timed_out")
        case .helperConnectionFailed:
            tr("app.system_proxy.alert.helper_connection_failed")
        case .helperOperationFailed:
            tr("app.system_proxy.alert.helper_operation_failed")
        case .appNotInApplications:
            tr("app.system_proxy.alert.helper_install_location")
        case .helperNotBundled:
            tr("app.system_proxy.alert.helper_not_bundled")
        case .signatureMismatch:
            tr("app.system_proxy.alert.helper_invalid_signature")
        case .unknown:
            tr("app.system_proxy.alert.unknown")
        }
    }

    private func normalizedSystemProxyComparisonHost(_ host: String) -> String {
        switch host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "localhost", "127.0.0.1", "0.0.0.0", "::1", "::", "0:0:0:0:0:0:0:0":
            "loopback"
        default:
            host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    func normalizedSystemProxyExceptionValues(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        for value in values {
            let trimmed = value.trimmed
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }

    func currentSystemProxyExceptionValues() -> [String] {
        self.normalizedSystemProxyExceptionValues(self.systemProxyExceptions.map(\.value))
    }

    private func systemProxyExceptionRows(from values: [String]) -> [EditableSystemProxyException] {
        self.normalizedSystemProxyExceptionValues(values).map { EditableSystemProxyException(value: $0) }
    }

    @discardableResult
    private func runSystemProxySettingsOperation(
        syncingKey: String,
        successMessage: String,
        operation: () async throws -> Void) async -> Bool
    {
        self.settingsFeedbackClearTask?.cancel()
        self.settingsFeedbackClearTask = nil
        self.settingsSyncingKey = syncingKey
        self.settingsErrorMessage = nil
        self.settingsSavedMessage = nil
        defer { self.settingsSyncingKey = nil }

        do {
            try await operation()
            self.settingsSavedMessage = successMessage
            self.scheduleSettingsFeedbackAutoClearIfNeeded(message: successMessage)
            await self.refreshSystemProxyHelperStatus()
            if self.hasSystemProxyOpenIntent {
                await self.refreshSystemProxyStatus()
            }
            return true
        } catch {
            self.settingsErrorMessage = tr(
                "app.settings.error.save_failed",
                tr("ui.section.system_proxy_exceptions"),
                self.systemProxyErrorMessage(error))
            self.settingsSavedMessage = nil
            await self.refreshSystemProxyHelperStatus()
            return false
        }
    }
}
