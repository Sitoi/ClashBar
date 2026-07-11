import Combine
import Foundation

@MainActor
final class ProxyStore: ObservableObject {
    var proxyGroups: [ProxyGroup] = [] {
        willSet { self.publishChangeIfNeeded(current: self.proxyGroups, next: newValue) }
    }

    var groupLatencyLoading: Set<String> = [] {
        willSet { self.publishChangeIfNeeded(current: self.groupLatencyLoading, next: newValue) }
    }

    var groupLatencies: [String: [String: Int]] = [:] {
        willSet { self.publishChangeIfNeeded(current: self.groupLatencies, next: newValue) }
    }

    var proxyLatencyTesting: Set<ProxyLatencyTestKey> = [] {
        willSet { self.publishChangeIfNeeded(current: self.proxyLatencyTesting, next: newValue) }
    }

    var proxyHistoryLatestDelay: [String: Int] = [:] {
        willSet { self.publishChangeIfNeeded(current: self.proxyHistoryLatestDelay, next: newValue) }
    }

    var proxyNodeTypes: [String: String] = [:] {
        willSet { self.publishChangeIfNeeded(current: self.proxyNodeTypes, next: newValue) }
    }

    var isProxySyncing = false {
        willSet { self.publishChangeIfNeeded(current: self.isProxySyncing, next: newValue) }
    }

    var providerProxyCount = 0 {
        willSet { self.publishChangeIfNeeded(current: self.providerProxyCount, next: newValue) }
    }

    var providerRuleCount = 0 {
        willSet { self.publishChangeIfNeeded(current: self.providerRuleCount, next: newValue) }
    }

    var proxyProvidersDetail: [String: ProviderDetail] = [:] {
        willSet { self.publishChangeIfNeeded(current: self.proxyProvidersDetail, next: newValue) }
    }

    var sortedProxyProviderNames: [String] {
        self.proxyProvidersDetail.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var providerUpdating: Set<String> = [] {
        willSet { self.publishChangeIfNeeded(current: self.providerUpdating, next: newValue) }
    }

    var providerRefreshStatus: ProviderRefreshStatus = .idle {
        willSet { self.publishChangeIfNeeded(current: self.providerRefreshStatus, next: newValue) }
    }

    var rulesCount = 0 {
        willSet { self.publishChangeIfNeeded(current: self.rulesCount, next: newValue) }
    }

    var ruleProviders: [String: ProviderDetail] = [:] {
        willSet { self.publishChangeIfNeeded(current: self.ruleProviders, next: newValue) }
    }

    var ruleItems: [RuleItem] = [] {
        willSet { self.publishChangeIfNeeded(current: self.ruleItems, next: newValue) }
    }

    var isRuleProvidersRefreshing = false {
        willSet { self.publishChangeIfNeeded(current: self.isRuleProvidersRefreshing, next: newValue) }
    }

    private func publishChangeIfNeeded<Value: Equatable>(current: Value, next: Value) {
        guard current != next else { return }
        self.objectWillChange.send()
    }
}
