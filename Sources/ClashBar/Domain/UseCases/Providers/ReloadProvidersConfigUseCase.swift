import Foundation

struct ReloadProvidersConfigUseCase {
    private let repository: any ProvidersRepository

    init(repository: any ProvidersRepository) {
        self.repository = repository
    }

    func execute(force: Bool) async throws {
        try await self.repository.reloadConfig(force: force)
    }
}
