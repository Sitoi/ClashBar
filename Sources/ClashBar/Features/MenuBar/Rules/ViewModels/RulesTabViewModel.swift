import Foundation
import SwiftUI

@MainActor
final class RulesTabViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase

    @Published private(set) var visibleRules: [RuleItem] = []
    @Published private(set) var providerLookup: [String: ProviderDetail] = [:]

    init(presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase()) {
        self.presentRulesUseCase = presentRulesUseCase
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let output = self.presentRulesUseCase.execute(items: items, providers: providers)
        let nextRules = output.rules
        let nextLookup = output.providerLookup

        if nextRules != self.visibleRules {
            self.visibleRules = nextRules
        }

        guard nextLookup != self.providerLookup else { return }
        self.providerLookup = nextLookup
    }
}
