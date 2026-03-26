import Foundation

protocol ProvidersRepository: Sendable {
    func fetchProxyProviders() async throws -> ProviderSummary
    func fetchRuleProviders() async throws -> ProviderSummary
    func fetchRules() async throws -> RulesSummary
    func updateProxyProvider(name: String) async throws
    func updateRuleProvider(name: String) async throws
    func reloadConfig(force: Bool) async throws
}
