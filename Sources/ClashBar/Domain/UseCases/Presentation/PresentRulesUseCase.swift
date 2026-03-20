import Foundation

struct PresentRulesOutput {
    let rules: [RuleItem]
    let providerLookup: [String: ProviderDetail]
}

struct PresentRulesUseCase {
    func execute(items: [RuleItem], providers: [String: ProviderDetail]) -> PresentRulesOutput {
        PresentRulesOutput(
            rules: Array(items.prefix(100)),
            providerLookup: self.makeProviderLookup(from: providers))
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
