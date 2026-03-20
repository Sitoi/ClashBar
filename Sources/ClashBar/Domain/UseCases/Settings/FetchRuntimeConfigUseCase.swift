import Foundation

struct FetchRuntimeConfigUseCase {
    private let repository: any RuntimeConfigRepository

    init(repository: any RuntimeConfigRepository) {
        self.repository = repository
    }

    func execute() async throws -> ConfigSnapshot {
        try await self.repository.fetchConfig()
    }
}
