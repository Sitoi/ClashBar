import Foundation

@MainActor
struct CheckSystemProxyConfiguredUseCase {
    private let repository: any SystemProxyRepository

    init(repository: any SystemProxyRepository) {
        self.repository = repository
    }

    func execute(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try await self.repository.isConfigured(host: host, ports: ports)
    }
}
