import Foundation

struct CloseConnectionUseCase {
    private let repository: any ConnectionsRepository

    init(repository: any ConnectionsRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await self.repository.closeConnection(id: id)
    }
}
