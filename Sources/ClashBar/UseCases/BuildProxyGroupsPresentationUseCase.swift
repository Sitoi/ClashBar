import Foundation

struct ProxyGroupsPresentation {
    let groups: [ProxyGroup]
    let delaySamples: [String: [Int]]
    let nodeTypes: [String: String]
}

struct BuildProxyGroupsPresentationUseCase {
    func execute(
        response: ProxyGroupsResponse,
        proxyProviders: [String: ProviderDetail],
        fallbackProxyProviders: [String: ProviderDetail]) -> ProxyGroupsPresentation
    {
        let providerLookup = proxyProviders.isEmpty ? fallbackProxyProviders : proxyProviders
        let proxiesWithHealthcheckConfig = response.proxies.values.map { proxy in
            let provider = providerLookup[proxy.name]
            let resolvedTestURL = proxy.testUrl?.trimmedNonEmpty ?? provider?.testUrl?.trimmedNonEmpty
            let resolvedTimeout = proxy.timeout.flatMap { $0 > 0 ? $0 : nil }
                ?? provider?.timeout.flatMap { $0 > 0 ? $0 : nil }

            return ProxyGroup(
                name: proxy.name,
                type: proxy.type,
                now: proxy.now,
                all: proxy.all,
                testUrl: resolvedTestURL,
                timeout: resolvedTimeout,
                icon: proxy.icon,
                hidden: proxy.hidden,
                delayHistory: proxy.delayHistory)
        }

        let sortIndex = (response.proxies["GLOBAL"]?.all ?? []) + ["GLOBAL"]
        var sortIndexMap: [String: Int] = [:]
        for (index, name) in sortIndex.enumerated() where sortIndexMap[name] == nil {
            sortIndexMap[name] = index
        }

        let groups = proxiesWithHealthcheckConfig
            .enumerated()
            .filter { !$0.element.all.isEmpty }
            .sorted { lhs, rhs in
                let lhsOrder = sortIndexMap[lhs.element.name] ?? .max
                let rhsOrder = sortIndexMap[rhs.element.name] ?? .max

                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }

                return lhs.element.name.localizedCaseInsensitiveCompare(rhs.element.name) == .orderedAscending
            }
            .map(\.element)

        var delaySamples: [String: [Int]] = [:]
        var nodeTypes: [String: String] = [:]
        for proxy in response.proxies.values {
            if proxy.all.isEmpty, let type = proxy.type.trimmedNonEmpty {
                nodeTypes[proxy.name] = type
            }
            if !proxy.delayHistory.isEmpty {
                delaySamples[proxy.name] = proxy.delayHistory
            }
        }

        for provider in providerLookup.values {
            for node in provider.proxies ?? [] {
                if !node.delayHistory.isEmpty, delaySamples[node.name] == nil {
                    delaySamples[node.name] = node.delayHistory
                }
                if let type = node.type.trimmedNonEmpty, nodeTypes[node.name] == nil {
                    nodeTypes[node.name] = type
                }
            }
        }

        return ProxyGroupsPresentation(
            groups: groups,
            delaySamples: delaySamples,
            nodeTypes: nodeTypes)
    }
}
