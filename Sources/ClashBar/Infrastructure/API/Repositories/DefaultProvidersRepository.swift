import Foundation

struct DefaultProvidersRepository: ProvidersRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func fetchProxyProviders() async throws -> ProviderSummary {
        try await self.transport.request(.proxyProviders)
    }

    func fetchRuleProviders() async throws -> ProviderSummary {
        try await self.transport.request(.ruleProviders)
    }

    func fetchRules() async throws -> RulesSummary {
        try await self.transport.request(.rules)
    }

    func updateProxyProvider(name: String) async throws {
        try await self.transport.requestNoResponse(.updateProxyProvider(name: name))
    }

    func updateRuleProvider(name: String) async throws {
        try await self.transport.requestNoResponse(.updateRuleProvider(name: name))
    }

    func reloadConfig(force: Bool) async throws {
        try await self.transport.requestNoResponse(.putConfigs(force: force))
    }
}
