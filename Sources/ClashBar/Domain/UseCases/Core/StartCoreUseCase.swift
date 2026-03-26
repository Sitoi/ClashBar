import Foundation

@MainActor
struct StartCoreUseCase {
    private let coreRepository: any CoreRepository

    init(coreRepository: any CoreRepository) {
        self.coreRepository = coreRepository
    }

    @discardableResult
    func execute(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.coreRepository.start(configPath: configPath, controller: controller)
    }
}
