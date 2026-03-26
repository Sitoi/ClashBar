import Foundation

protocol ProxyGroupsRepository: Sendable {
    func fetchProxyGroups() async throws -> ProxyGroupsResponse
}
