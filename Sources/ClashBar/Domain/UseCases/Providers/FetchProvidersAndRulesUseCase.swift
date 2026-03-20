import Foundation

struct ProvidersAndRulesSnapshot {
    let proxyProviders: ProviderSummary
    let ruleProviders: ProviderSummary
    let rules: RulesSummary
}

struct FetchProvidersAndRulesUseCase {
    private let repository: any ProvidersRepository

    init(repository: any ProvidersRepository) {
        self.repository = repository
    }

    func execute() async throws -> ProvidersAndRulesSnapshot {
        async let proxyProviders = self.repository.fetchProxyProviders()
        async let ruleProviders = self.repository.fetchRuleProviders()
        async let rules = self.repository.fetchRules()

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
