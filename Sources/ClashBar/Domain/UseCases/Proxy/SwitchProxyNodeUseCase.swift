import Foundation

struct SwitchProxyNodeUseCase {
    private let repository: any ProxyRepository

    init(repository: any ProxyRepository) {
        self.repository = repository
    }

    func execute(group: String, target: String) async throws {
        try await self.repository.switchProxy(group: group, target: target)
    }
}
