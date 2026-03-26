import Foundation
import SwiftUI

@MainActor
final class MenuBarRootViewModel: ObservableObject {
    @Published var currentTab: RootTab = .proxy
    @Published private(set) var filteredProxyGroups: [ProxyGroup] = []

    func syncCurrentTab(_ tab: RootTab) {
        self.currentTab = tab
    }

    func updateFilteredProxyGroups(from groups: [ProxyGroup], hideHiddenGroups: Bool) {
        let nextGroups = hideHiddenGroups ? groups.filter { $0.hidden != true } : groups
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }
}
