import Foundation

struct UpgradeCoreUseCase {
    private let repository: any MaintenanceRepository

    init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    func execute() async throws -> CoreUpgradeResponse {
        try await self.repository.upgradeCore()
    }
}
