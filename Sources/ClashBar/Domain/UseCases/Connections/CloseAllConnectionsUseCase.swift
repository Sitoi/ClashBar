import Foundation

struct CloseAllConnectionsUseCase {
    private let repository: any ConnectionsRepository

    init(repository: any ConnectionsRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await self.repository.closeAllConnections()
    }
}
