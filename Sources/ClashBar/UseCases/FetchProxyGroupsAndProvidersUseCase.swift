import Foundation

struct ProxyGroupsAndProvidersSnapshot {
    let groups: ProxyGroupsResponse
    let providers: [String: ProviderDetail]
    let providersError: Error?
}

struct FetchProxyGroupsAndProvidersUseCase {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func execute() async throws -> ProxyGroupsAndProvidersSnapshot {
        async let groupsTask: ProxyGroupsResponse = self.transport.request(.proxies)
        let resolvedGroups = try await groupsTask

        do {
            let providers: ProviderSummary = try await self.transport.request(.proxyProviders)
            return ProxyGroupsAndProvidersSnapshot(
                groups: resolvedGroups,
                providers: providers.providers,
                providersError: nil)
        } catch {
            return ProxyGroupsAndProvidersSnapshot(
                groups: resolvedGroups,
                providers: [:],
                providersError: error)
        }
    }
}
