import Foundation

struct FetchVersionUseCase {
    private let repository: any MaintenanceRepository

    init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    func execute() async throws -> VersionInfo {
        try await self.repository.fetchVersion()
    }
}
