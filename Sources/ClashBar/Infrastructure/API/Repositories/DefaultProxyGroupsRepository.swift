import Foundation

struct DefaultProxyGroupsRepository: ProxyGroupsRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func fetchProxyGroups() async throws -> ProxyGroupsResponse {
        try await self.transport.request(.proxies)
    }
}
