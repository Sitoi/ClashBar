import Foundation

struct ProvidersAndRulesSnapshot {
    let proxyProviders: ProviderSummary
    let ruleProviders: ProviderSummary
    let rules: RulesSummary
}

struct FetchProvidersAndRulesUseCase {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func execute() async throws -> ProvidersAndRulesSnapshot {
        async let proxyProviders: ProviderSummary = self.transport.request(.proxyProviders)
        async let ruleProviders: ProviderSummary = self.transport.request(.ruleProviders)
        async let rules: RulesSummary = self.transport.request(.rules)

        let (resolvedProxyProviders, resolvedRuleProviders, resolvedRules) = try await (
            proxyProviders,
            ruleProviders,
            rules)

        return ProvidersAndRulesSnapshot(
            proxyProviders: resolvedProxyProviders,
            ruleProviders: resolvedRuleProviders,
            rules: resolvedRules)
    }
}
