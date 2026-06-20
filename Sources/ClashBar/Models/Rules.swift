import Foundation

struct RulesSummary: Decodable, Equatable {
    /// 安全上限，防止异常配置撑爆内存；真实配置（几千条）远低于此，等效于无限制。
    static let retainedRuleLimit = 20000

    let rules: [RuleItem]
    let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case rules
    }

    init(rules: [RuleItem], totalCount: Int? = nil) {
        self.rules = rules
        self.totalCount = totalCount ?? rules.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard var rulesContainer = try? container.nestedUnkeyedContainer(forKey: .rules) else {
            self.rules = []
            self.totalCount = 0
            return
        }

        var retained: [RuleItem] = []
        retained.reserveCapacity(min(Self.retainedRuleLimit, rulesContainer.count ?? Self.retainedRuleLimit))

        var totalCount = 0
        while !rulesContainer.isAtEnd {
            let rule = try rulesContainer.decode(RuleItem.self)
            if retained.count < Self.retainedRuleLimit {
                retained.append(rule)
            }
            totalCount += 1
        }

        self.rules = retained
        self.totalCount = totalCount
    }
}

struct RuleItem: Decodable, Hashable {
    let type: String?
    let payload: String?
    let proxy: String?
}
