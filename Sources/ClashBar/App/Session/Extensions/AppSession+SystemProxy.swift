import Foundation

@MainActor
extension AppSession {
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

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await self.checkSystemProxyConfiguredUseCase.execute(host: host, ports: ports)
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

            didCheckSystemProxyConsistencyOnLaunch = true
            await refreshSystemProxyStatus()
        } catch {
            appendLog(
                level: "error",
                message: tr("log.system_proxy.startup_repair_failed", self.systemProxyErrorMessage(error)))
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
        case .helperRequiresInstallToApplications:
            return tr("app.system_proxy.error.helper_install_location")
        case .helperNeedsApproval:
            return tr("app.system_proxy.error.helper_needs_approval")
        case let .helperRegistrationFailed(message):
            return tr("app.system_proxy.error.helper_registration_failed", message)
        case let .helperRecoveryFailed(message):
            return tr("app.system_proxy.error.helper_recovery_failed", message)
        case let .helperConnectionFailed(message):
            return tr("app.system_proxy.error.helper_connection_failed", message)
        case let .helperOperationFailed(message):
            return tr("app.system_proxy.error.helper_operation_failed", message)
        }
    }
}
