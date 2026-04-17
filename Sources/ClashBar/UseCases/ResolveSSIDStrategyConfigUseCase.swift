import Foundation

struct ResolveSSIDStrategyConfigUseCase {
    enum Resolution: Equatable {
        case noAction
        case switchToConfig(String)
        case missingConfig(String)
    }

    func execute(
        currentSSID: String?,
        currentConfigName: String?,
        rules: [SSIDStrategyRule],
        availableConfigNames: [String]) -> Resolution
    {
        guard let normalizedSSID = currentSSID?.trimmedNonEmpty else {
            return .noAction
        }

        let normalizedRules = SSIDStrategyRule.normalized(rules)
        guard let matchedRule = normalizedRules.first(where: { $0.ssid == normalizedSSID }) else {
            return .noAction
        }

        let targetConfigName = matchedRule.configFileName
        guard Set(availableConfigNames.map(\.trimmed)).contains(targetConfigName) else {
            return .missingConfig(targetConfigName)
        }

        if targetConfigName == currentConfigName?.trimmed {
            return .noAction
        }

        return .switchToConfig(targetConfigName)
    }
}
