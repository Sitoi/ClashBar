import Foundation

struct FlushDNSCacheUseCase {
    private let repository: any MaintenanceRepository

    init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await self.repository.flushDNSCache()
    }
}
