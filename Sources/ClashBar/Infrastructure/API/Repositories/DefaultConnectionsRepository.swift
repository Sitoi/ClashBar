import Foundation

struct DefaultConnectionsRepository: ConnectionsRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func closeAllConnections() async throws {
        try await self.transport.requestNoResponse(.closeAllConnections)
    }

    func closeConnection(id: String) async throws {
        try await self.transport.requestNoResponse(.closeConnection(id: id))
    }
}
