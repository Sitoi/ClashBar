import Foundation

@MainActor
struct ReadSystemProxyEnabledStateUseCase {
    private let repository: any SystemProxyRepository

    init(repository: any SystemProxyRepository) {
        self.repository = repository
    }

    func execute() async throws -> Bool {
        try await self.repository.isEnabled()
    }
}
