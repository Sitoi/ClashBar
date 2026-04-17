import Foundation

struct SSIDStrategyRule: Codable, Equatable {
    var ssid: String
    var configFileName: String
}

extension SSIDStrategyRule {
    static func normalized(_ rules: [SSIDStrategyRule]) -> [SSIDStrategyRule] {
        var normalizedRules: [SSIDStrategyRule] = []
        var indexesBySSID: [String: Int] = [:]

        for rule in rules {
            let normalizedSSID = rule.ssid.trimmed
            let normalizedConfigFileName = rule.configFileName.trimmed
            guard !normalizedSSID.isEmpty, !normalizedConfigFileName.isEmpty else { continue }

            let normalizedRule = SSIDStrategyRule(
                ssid: normalizedSSID,
                configFileName: normalizedConfigFileName)

            if let existingIndex = indexesBySSID[normalizedSSID] {
                normalizedRules[existingIndex] = normalizedRule
            } else {
                indexesBySSID[normalizedSSID] = normalizedRules.count
                normalizedRules.append(normalizedRule)
            }
        }

        return normalizedRules
    }

    static func upserting(
        ssid: String,
        configFileName: String,
        into rules: [SSIDStrategyRule]) -> [SSIDStrategyRule]
    {
        let normalizedSSID = ssid.trimmed
        let normalizedConfigFileName = configFileName.trimmed
        guard !normalizedSSID.isEmpty, !normalizedConfigFileName.isEmpty else {
            return Self.normalized(rules)
        }

        return Self.normalized(rules + [SSIDStrategyRule(
            ssid: normalizedSSID,
            configFileName: normalizedConfigFileName)])
    }

    static func removing(ssid: String, from rules: [SSIDStrategyRule]) -> [SSIDStrategyRule] {
        let normalizedSSID = ssid.trimmed
        guard !normalizedSSID.isEmpty else {
            return Self.normalized(rules)
        }

        return Self.normalized(rules).filter { $0.ssid != normalizedSSID }
    }
}
