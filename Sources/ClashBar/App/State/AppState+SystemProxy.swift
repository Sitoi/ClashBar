import Foundation

@MainActor
extension AppState {
    func applySystemProxy(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try await systemProxyService.applySystemProxy(enabled: enabled, host: host, ports: ports)
    }

    func readSystemProxyEnabledState() async throws -> Bool {
        try await systemProxyService.isSystemProxyEnabled()
    }

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await systemProxyService.isSystemProxyConfigured(host: host, ports: ports)
    }

    func systemProxyPorts(from config: ConfigSnapshot) -> SystemProxyPorts {
        if let mixed = normalizedSystemProxyPort(config.mixedPort) {
            return SystemProxyPorts(httpPort: mixed, httpsPort: mixed, socksPort: mixed)
        }

        let httpPort = normalizedSystemProxyPort(config.port)
        return SystemProxyPorts(
            httpPort: httpPort,
            httpsPort: httpPort,
            socksPort: normalizedSystemProxyPort(config.socksPort)
        )
    }

    func currentSystemProxyPortsFromState() -> SystemProxyPorts {
        if let mixed = normalizedSystemProxyPort(mixedPort) {
            return SystemProxyPorts(httpPort: mixed, httpsPort: mixed, socksPort: mixed)
        }

        let httpPort = normalizedSystemProxyPort(port)
        return SystemProxyPorts(
            httpPort: httpPort,
            httpsPort: httpPort,
            socksPort: normalizedSystemProxyPort(socksPort)
        )
    }

    func resolveSystemProxyTargetFromRuntimeConfig() async throws -> (host: String, ports: SystemProxyPorts) {
        let config = try await fetchRuntimeConfigSnapshot()
        let ports = systemProxyPorts(from: config)
        guard ports.hasEnabledPort else {
            throw SystemProxyServiceError.invalidPort
        }
        return (host: controllerHost(), ports: ports)
    }

    func normalizedSystemProxyPort(_ value: Int?) -> Int? {
        guard let value, (1...65535).contains(value) else {
            return nil
        }
        return value
    }

    func ensureSystemProxyConsistencyOnFirstLaunchIfNeeded() async {
        guard !didCheckSystemProxyConsistencyOnLaunch else { return }
        didCheckSystemProxyConsistencyOnLaunch = true
        guard isSystemProxyEnabled else { return }

        do {
            let target = try await resolveSystemProxyTargetFromRuntimeConfig()
            let isConfigured = try await isSystemProxyConfigured(host: target.host, ports: target.ports)
            guard !isConfigured else { return }

            try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
            appendLog(
                level: "info",
                message: tr("log.system_proxy.startup_repaired", target.host, target.ports.primaryPort ?? 0)
            )
            await refreshSystemProxyStatus()
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.startup_repair_failed", systemProxyErrorMessage(error)))
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
