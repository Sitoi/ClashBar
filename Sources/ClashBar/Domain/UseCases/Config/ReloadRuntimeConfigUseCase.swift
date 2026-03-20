import Foundation

struct ReloadRuntimeConfigUseCase {
    private let repository: any RuntimeConfigRepository

    init(repository: any RuntimeConfigRepository) {
        self.repository = repository
    }

    func execute(force: Bool) async throws {
        try await self.repository.reloadConfig(force: force)
    }
}
