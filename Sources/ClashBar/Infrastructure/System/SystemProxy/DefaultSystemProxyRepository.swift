import Foundation

@MainActor
final class DefaultSystemProxyRepository: SystemProxyRepository {
    private let service: SystemProxyService

    init(service: SystemProxyService) {
        self.service = service
    }

    func apply(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try await self.service.applySystemProxy(enabled: enabled, host: host, ports: ports)
    }

    func isEnabled() async throws -> Bool {
        try await self.service.isSystemProxyEnabled()
    }

    func readActiveDisplay() async throws -> String? {
        try await self.service.readSystemProxyActiveDisplay()
    }

    func isConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await self.service.isSystemProxyConfigured(host: host, ports: ports)
    }

    func diagnoseCurrentHelper() async -> SystemProxyHelperDiagnosis {
        await self.service.diagnoseCurrentHelper()
    }

    func diagnoseAndRepair() async -> SystemProxyHelperDiagnosis {
        await self.service.diagnoseAndRepairHelper()
    }

    func installHelper() async -> SystemProxyHelperDiagnosis {
        await self.service.installHelperManually()
    }

    func reinstallHelper() async -> SystemProxyHelperDiagnosis {
        await self.service.reinstallHelperManually()
    }

    func warmUpHelperIfPossible() async {
        await self.service.warmUpHelperIfPossible()
    }

    func clearBlocking(timeout: TimeInterval = 2.0) {
        self.service.clearSystemProxyBlocking(timeout: timeout)
    }
}
