import Foundation

@MainActor
extension AppSession {
    private func helperIssue(from message: String?) -> SystemProxyHelperIssue {
        let normalized = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return .none }
        if normalized.contains("not installed") {
            return .notInstalled
        }
        if normalized.contains("blocked by system policy")
            || normalized.contains("operation not permitted")
            || normalized.contains("disallowed")
            || normalized.contains("background item")
            || normalized.contains("launch constraint")
        {
            return .systemPolicyBlocked
        }
        if normalized.contains("teamidentifier") || normalized.contains("signature")
            || normalized.contains("codesign") || normalized.contains("code signing")
        {
            return .signatureMismatch
        }
        if normalized.contains("requires approval") || normalized.contains("login items") {
            return .needsApproval
        }
        if normalized.contains("/applications") || normalized.contains("read-only") {
            return .installLocationInvalid
        }
        if normalized.contains("not found in app bundle") || normalized.contains("not bundled") {
            return .helperMissing
        }
        if normalized.contains("timed out") {
            return .timeout
        }
        if normalized.contains("failed to connect privileged helper")
            || normalized.contains("unable to create xpc proxy")
            || normalized.contains("xpc")
        {
            return .connectionFailed
        }
        if normalized.contains("failed to register privileged helper")
            || normalized.contains("not enabled. use reinstall helper")
        {
            return .registrationFailed
        }
        if normalized.contains("migration") || normalized.contains("reinstall") || normalized.contains("cleanup") {
            return .migrationFailed
        }
        if normalized.contains("privileged helper operation failed") {
            return .operationFailed
        }
        if normalized.contains("permission denied") {
            return .permissionDenied
        }
        if normalized.contains("register"), normalized.contains("error: 1") {
            return .registrationFailed
        }
        return .unknown
    }

    private func applyHelperDiagnosis(_ diagnosis: SystemProxyHelperDiagnosis) {
        switch diagnosis {
        case .healthy:
            self.systemProxyHelperState = .running
            self.systemProxyHelperIssue = .none
            self.systemProxyHelperFailureMessage = nil
        case let .failed(message):
            self.systemProxyHelperState = .failed
            self.systemProxyHelperIssue = self.helperIssue(from: message)
            self.systemProxyHelperFailureMessage = message
            appendLog(level: "error", message: tr("log.system_proxy.helper_failed", message))
        }
    }

    private var resolveSystemProxyPortsUseCase: ResolveSystemProxyPortsUseCase {
        ResolveSystemProxyPortsUseCase()
    }

    private var applySystemProxyUseCase: ApplySystemProxyUseCase {
        ApplySystemProxyUseCase(repository: self.systemProxyRepository)
    }

    private var readSystemProxyEnabledStateUseCase: ReadSystemProxyEnabledStateUseCase {
        ReadSystemProxyEnabledStateUseCase(repository: self.systemProxyRepository)
    }

    private var checkSystemProxyConfiguredUseCase: CheckSystemProxyConfiguredUseCase {
        CheckSystemProxyConfiguredUseCase(repository: self.systemProxyRepository)
    }

    func applySystemProxy(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try await self.applySystemProxyUseCase.execute(enabled: enabled, host: host, ports: ports)
    }

    func readSystemProxyEnabledState() async throws -> Bool {
        try await self.readSystemProxyEnabledStateUseCase.execute()
    }

    func readSystemProxyActiveDisplay() async throws -> String? {
        try await self.systemProxyRepository.readActiveDisplay()
    }

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await self.checkSystemProxyConfiguredUseCase.execute(host: host, ports: ports)
    }

    func refreshSystemProxyHelperStatus() async {
        let diagnosis = await self.systemProxyRepository.diagnoseCurrentHelper()
        self.applyHelperDiagnosis(diagnosis)
    }

    func installSystemProxyHelper() async {
        guard !self.systemProxyHelperActionInFlight else { return }
        self.systemProxyHelperActionInFlight = true
        self.systemProxyHelperActionState = .installing
        defer {
            self.systemProxyHelperActionInFlight = false
            self.systemProxyHelperActionState = .idle
        }

        appendLog(level: "info", message: tr("log.system_proxy.helper_installing"))
        let diagnosis = await self.systemProxyRepository.installHelper()
        self.applyHelperDiagnosis(diagnosis)
    }

    func reinstallSystemProxyHelper() async {
        guard !self.systemProxyHelperActionInFlight else { return }
        self.systemProxyHelperActionInFlight = true
        self.systemProxyHelperActionState = .reinstalling
        defer {
            self.systemProxyHelperActionInFlight = false
            self.systemProxyHelperActionState = .idle
        }

        appendLog(level: "info", message: tr("log.system_proxy.helper_reinstalling"))
        let diagnosis = await self.systemProxyRepository.reinstallHelper()
        self.applyHelperDiagnosis(diagnosis)
    }

    func systemProxyPorts(from config: ConfigSnapshot) -> SystemProxyPorts {
        self.resolveSystemProxyPortsUseCase.execute(
            mixedPort: config.mixedPort,
            httpPort: config.port,
            socksPort: config.socksPort)
    }

    func currentSystemProxyPortsFromState() -> SystemProxyPorts {
        self.resolveSystemProxyPortsUseCase.execute(
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
            self.systemProxyHelperState = .running
            self.systemProxyHelperIssue = .none
            self.systemProxyHelperFailureMessage = nil
            systemProxyActiveDisplay = buildSystemProxyDisplayString(host: target.host, ports: target.ports)

            didCheckSystemProxyConsistencyOnLaunch = true
            await refreshSystemProxyStatus()
        } catch {
            appendLog(
                level: "error",
                message: tr("log.system_proxy.startup_repair_failed", self.systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
        }
    }

    func scheduleSystemProxyStartupPostflight(
        refreshStatusBeforeOverlay: Bool,
        refreshStatusAfterBootstrap: Bool)
    {
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
        case .helperNotInstalled:
            return tr("app.system_proxy.error.helper_not_installed")
        case .helperRequiresInstallToApplications:
            return tr("app.system_proxy.error.helper_install_location")
        case .helperNeedsApproval:
            return tr("app.system_proxy.error.helper_needs_approval")
        case let .helperBlockedBySystemPolicy(message):
            return tr("app.system_proxy.error.helper_blocked_by_system_policy", message)
        case let .helperInvalidSignature(message):
            return tr("app.system_proxy.error.helper_invalid_signature", message)
        case let .helperRegistrationFailed(message):
            return tr("app.system_proxy.error.helper_registration_failed", message)
        case let .helperConnectionFailed(message):
            return tr("app.system_proxy.error.helper_connection_failed", message)
        case let .helperOperationFailed(message):
            return tr("app.system_proxy.error.helper_operation_failed", message)
        }
    }
}
