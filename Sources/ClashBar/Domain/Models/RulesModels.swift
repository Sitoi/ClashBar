import Foundation

struct RulesSummary: Decodable, Equatable {
    static let retainedRuleLimit = 100

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

struct RuleItem: Decodable, Equatable, Identifiable {
    let rowID: UUID
    let type: String?
    let payload: String?
    let proxy: String?

    var id: UUID {
        self.rowID
    }

    static func == (lhs: RuleItem, rhs: RuleItem) -> Bool {
        lhs.type == rhs.type && lhs.payload == rhs.payload && lhs.proxy == rhs.proxy
    }

    private enum CodingKeys: String, CodingKey {
        case type, payload, proxy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rowID = UUID()
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.payload = try container.decodeIfPresent(String.self, forKey: .payload)
        self.proxy = try container.decodeIfPresent(String.self, forKey: .proxy)
    }
}
