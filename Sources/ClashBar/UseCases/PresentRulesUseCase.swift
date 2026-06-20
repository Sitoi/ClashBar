import Foundation

struct PresentRulesOutput: Equatable {
    let rules: [RuleItem]
    let groups: [RuleGroup]
    let providerLookup: [String: ProviderDetail]
    let policyOptions: [RulePolicyOption]
    let typeCounts: [RulesTypeFilter: Int]

    static let empty = PresentRulesOutput(
        rules: [], groups: [], providerLookup: [:], policyOptions: [.all], typeCounts: [:])
}

struct PresentRulesUseCase {
    func execute(
        items: [RuleItem],
        providers: [String: ProviderDetail],
        filter: RulesFilter) -> PresentRulesOutput
    {
        let policyOptions = self.makePolicyOptions(from: items)
        let keyword = filter.filterText.trimmed
        let policyFilter = filter.policyFilter
        let typeFilter = filter.typeFilter

        // base：仅按关键字 + 策略过滤（不含类型），既用于按类型计数，也是类型过滤的输入。
        let base: [RuleItem] = if keyword.isEmpty, policyFilter.isAll {
            items
        } else {
            items.filter { rule in
                guard policyFilter.isAll || rule.proxy.trimmedOrEmpty == policyFilter.name else { return false }
                guard keyword.isEmpty || self.searchText(for: rule).localizedStandardContains(keyword) else {
                    return false
                }
                return true
            }
        }

        let typeCounts = self.makeTypeCounts(from: base)
        let filtered = typeFilter == .all ? base : base.filter { typeFilter.matches($0.type) }

        return PresentRulesOutput(
            rules: filtered,
            groups: filter.groupByPolicy ? self.makeGroups(from: filtered) : [],
            providerLookup: self.makeProviderLookup(from: providers),
            policyOptions: policyOptions,
            typeCounts: typeCounts)
    }

    private func makeTypeCounts(from rules: [RuleItem]) -> [RulesTypeFilter: Int] {
        var counts: [RulesTypeFilter: Int] = [.all: rules.count]
        for rule in rules {
            for filter in RulesTypeFilter.allCases where filter != .all && filter.matches(rule.type) {
                counts[filter, default: 0] += 1
                break // 每条规则恰好归入一个类型桶
            }
        }
        return counts
    }

    private func makeGroups(from rules: [RuleItem]) -> [RuleGroup] {
        var buckets: [String: [RuleItem]] = [:]
        for rule in rules {
            buckets[rule.proxy.trimmedOrEmpty, default: []].append(rule)
        }

        // 规则数多的策略排前面，数量相同按名称稳定排序。
        return buckets.map { RuleGroup(policy: $0.key, rules: $0.value) }.sorted { lhs, rhs in
            lhs.rules.count != rhs.rules.count
                ? lhs.rules.count > rhs.rules.count
                : lhs.policy.localizedStandardCompare(rhs.policy) == .orderedAscending
        }
    }

    private func searchText(for rule: RuleItem) -> String {
        "\(rule.payload.trimmedOrEmpty) \(rule.type.trimmedOrEmpty) \(rule.proxy.trimmedOrEmpty)"
    }

    private func makePolicyOptions(from items: [RuleItem]) -> [RulePolicyOption] {
        let names = Set(items.compactMap(\.proxy.trimmedNonEmpty))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return [.all] + names.map { RulePolicyOption(name: $0) }
    }

    private func makeProviderLookup(from providers: [String: ProviderDetail]) -> [String: ProviderDetail] {
        var map: [String: ProviderDetail] = [:]
        map.reserveCapacity(providers.count * 2)

        for (key, detail) in providers {
            map[key.lowercased()] = detail
            if let name = detail.name.trimmedNonEmpty {
                map[name.lowercased()] = detail
            }
        }

        return map
    }
}
