import Foundation
import SwiftUI

enum RulesTypeFilter: String, CaseIterable, Identifiable {
    case all
    case domain
    case ip
    case ruleSet
    case other

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .all:
            "ui.rules.type.all"
        case .domain:
            "ui.rules.type.domain"
        case .ip:
            "ui.rules.type.ip"
        case .ruleSet:
            "ui.rules.type.ruleset"
        case .other:
            "ui.rules.type.other"
        }
    }

    func matches(_ type: String?) -> Bool {
        guard self != .all else { return true }
        let normalized = type.trimmedOrEmpty.lowercased()
        guard !normalized.isEmpty else { return self == .other }

        // 判断顺序很重要：rule-set 优先，其次 domain/geosite，再 ip/geoip，否则 other。
        if normalized.contains("rule-set") || normalized.contains("ruleset") {
            return self == .ruleSet
        }
        if normalized.contains("domain") || normalized.contains("geosite") {
            return self == .domain
        }
        if normalized.contains("ip") || normalized.contains("geoip") {
            return self == .ip
        }
        return self == .other
    }
}

struct RulePolicyOption: Hashable, Identifiable {
    let name: String

    var id: String {
        self.name
    }

    var isAll: Bool {
        self.name.isEmpty
    }

    static let all = RulePolicyOption(name: "")
}

struct RuleGroup: Equatable, Identifiable {
    let policy: String
    let rules: [RuleItem]

    var id: String {
        self.policy
    }
}

struct RulesFilter: Equatable {
    var filterText: String = ""
    var typeFilter: RulesTypeFilter = .all
    var policyFilter: RulePolicyOption = .all
    var groupByPolicy: Bool = false
}

@MainActor
final class RulesViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase

    @Published var filterText: String = ""
    @Published var typeFilter: RulesTypeFilter = .all
    @Published var policyFilter: RulePolicyOption = .all
    @Published var groupByPolicy: Bool = false
    @Published private(set) var output: PresentRulesOutput = .empty

    init(presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase()) {
        self.presentRulesUseCase = presentRulesUseCase
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let next = self.presentRulesUseCase.execute(
            items: items,
            providers: providers,
            filter: RulesFilter(
                filterText: self.filterText,
                typeFilter: self.typeFilter,
                policyFilter: self.policyFilter,
                groupByPolicy: self.groupByPolicy))

        // 当前选中的策略在新选项里消失时（如刷新换配置），回落到全部（会触发再次刷新）。
        if !self.policyFilter.isAll, !next.policyOptions.contains(self.policyFilter) {
            self.policyFilter = .all
        }

        if next != self.output {
            self.output = next
        }
    }
}
