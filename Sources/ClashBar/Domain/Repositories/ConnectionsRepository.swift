import Foundation

protocol ConnectionsRepository: Sendable {
    func closeAllConnections() async throws
    func closeConnection(id: String) async throws
}
