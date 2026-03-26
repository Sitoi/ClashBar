import Foundation

struct UpdateRuleProviderUseCase {
    private let repository: any ProvidersRepository

    init(repository: any ProvidersRepository) {
        self.repository = repository
    }

    func execute(name: String) async throws {
        try await self.repository.updateRuleProvider(name: name)
    }
}
