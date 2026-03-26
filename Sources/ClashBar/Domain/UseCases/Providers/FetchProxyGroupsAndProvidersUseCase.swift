import Foundation

struct ProxyGroupsAndProvidersSnapshot {
    let groups: ProxyGroupsResponse
    let providers: [String: ProviderDetail]
}

struct FetchProxyGroupsAndProvidersUseCase {
    private let proxyGroupsRepository: any ProxyGroupsRepository
    private let providersRepository: any ProvidersRepository

    init(
        proxyGroupsRepository: any ProxyGroupsRepository,
        providersRepository: any ProvidersRepository)
    {
        self.proxyGroupsRepository = proxyGroupsRepository
        self.providersRepository = providersRepository
    }

    func execute() async throws -> ProxyGroupsAndProvidersSnapshot {
        async let groups = self.proxyGroupsRepository.fetchProxyGroups()
        async let providers: ProviderSummary? = try? await self.providersRepository.fetchProxyProviders()

        let (resolvedGroups, resolvedProviders) = try await (groups, providers)
        return ProxyGroupsAndProvidersSnapshot(
            groups: resolvedGroups,
            providers: resolvedProviders?.providers ?? [:])
    }
}
