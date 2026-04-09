import Foundation

struct ProxyGroupsAndProvidersSnapshot {
    let groups: ProxyGroupsResponse
    let providers: [String: ProviderDetail]
}

struct FetchProxyGroupsAndProvidersUseCase {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func execute() async throws -> ProxyGroupsAndProvidersSnapshot {
        async let groups: ProxyGroupsResponse = self.transport.request(.proxies)
        let resolvedGroups = try await groups
        let resolvedProviders: ProviderSummary? = try? await self.transport.request(.proxyProviders)
        return ProxyGroupsAndProvidersSnapshot(
            groups: resolvedGroups,
            providers: resolvedProviders?.providers ?? [:])
    }
}
