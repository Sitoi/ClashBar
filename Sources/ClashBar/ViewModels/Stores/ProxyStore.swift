import Foundation

// MARK: - ProxyStore

/// Owns proxy groups, provider details, latency, and rules state.
@MainActor
final class ProxyStore {
    weak var viewModel: AppViewModel?

    // MARK: - Proxy Groups

    var proxyGroups: [ProxyGroup] = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var groupLatencyLoading: Set<String> = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var groupLatencies: [String: [String: Int]] = [:] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var proxyLatencyTesting: Set<ProxyLatencyTestKey> = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var proxyHistoryLatestDelay: [String: Int] = [:] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var proxyNodeTypes: [String: String] = [:] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var isProxySyncing: Bool = false {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    // MARK: - Providers

    var providerProxyCount: Int = 0 {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var providerRuleCount: Int = 0 {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var proxyProvidersDetail: [String: ProviderDetail] = [:] {
        willSet { self.viewModel?.objectWillChange.send() }
        didSet {
            self.sortedProxyProviderNames = self.proxyProvidersDetail.keys.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
    }

    private(set) var sortedProxyProviderNames: [String] = []

    var providerUpdating: Set<String> = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var providerRefreshStatus: ProviderRefreshStatus = .idle {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    // MARK: - Rules

    var rulesCount: Int = 0 {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var ruleProviders: [String: ProviderDetail] = [:] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var ruleItems: [RuleItem] = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var isRuleProvidersRefreshing: Bool = false {
        willSet { self.viewModel?.objectWillChange.send() }
    }
}
