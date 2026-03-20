import Foundation

@MainActor
struct ApplySystemProxyUseCase {
    private let repository: any SystemProxyRepository

    init(repository: any SystemProxyRepository) {
        self.repository = repository
    }

    func execute(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try await self.repository.apply(enabled: enabled, host: host, ports: ports)
    }
}
