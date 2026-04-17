import Foundation
import SwiftUI

@MainActor
final class ProxyGroupsViewModel: ObservableObject {
    @Published var currentTab: RootTab = .proxy
    @Published private(set) var filteredProxyGroups: [ProxyGroup] = []

    func syncCurrentTab(_ tab: RootTab) {
        self.currentTab = tab
    }

    func updateFilteredProxyGroups(from groups: [ProxyGroup], hideHiddenGroups: Bool, currentMode: CoreMode) {
        let nextGroups = groups.filter { group in
            guard currentMode == .global || group.name.caseInsensitiveCompare("GLOBAL") != .orderedSame else {
                return false
            }
            return !hideHiddenGroups || group.hidden != true
        }
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }
}
