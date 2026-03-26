import Foundation

struct SwitchCoreModeUseCase {
    private let repository: any RuntimeConfigRepository

    init(repository: any RuntimeConfigRepository) {
        self.repository = repository
    }

    func execute(mode: CoreMode) async throws {
        try await self.repository.patchConfig(body: ["mode": .string(mode.rawValue)])
    }
}
