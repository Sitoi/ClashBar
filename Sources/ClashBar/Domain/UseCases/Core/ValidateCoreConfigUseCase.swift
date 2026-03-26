import Foundation

@MainActor
struct ValidateCoreConfigUseCase {
    private let coreRepository: any CoreRepository

    init(coreRepository: any CoreRepository) {
        self.coreRepository = coreRepository
    }

    func execute(configPath: String) async throws {
        try await self.coreRepository.validateConfig(configPath: configPath)
    }
}
