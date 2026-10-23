import SwiftUI

extension MenuBarRootView {
    private var hasMeasuredFixedSections: Bool {
        topHeaderHeight > 0 && modeAndTabSectionHeight > 0 && footerBarHeight > 0
    }

    private var hasResolvedCurrentTabLayout: Bool {
        self.hasMeasuredFixedSections && self.currentTabContentHeight > 0
    }

    private var fixedSectionHeight: CGFloat {
        topHeaderHeight + modeAndTabSectionHeight + footerBarHeight
    }

    var minimumPanelHeight: CGFloat {
        min(popoverLayoutModel.maxPanelHeight,
            max(popoverLayoutModel.minPanelHeight, self.fixedSectionHeight + self.currentTabHeaderHeight + 64))
    }

    var tabScrollAreaHeight: CGFloat {
        max(0, self.resolvedPanelHeight - self.fixedSectionHeight)
    }

    var resolvedPanelHeight: CGFloat {
        if let userPanelHeight = popoverLayoutModel.userPanelHeight {
            return min(popoverLayoutModel.maxPanelHeight, max(self.minimumPanelHeight, userPanelHeight))
        }
        guard self.hasResolvedCurrentTabLayout else { return popoverLayoutModel.resolvedPanelHeight }
        return min(popoverLayoutModel.maxPanelHeight,
                   max(self.minimumPanelHeight, self.fixedSectionHeight + self.currentTabContentHeight))
    }

    enum SectionHeightTarget {
        case header
        case modeAndTab
        case footer
    }

    func updateSectionHeight(_ measured: CGFloat, target: SectionHeightTarget) {
        let normalized = max(0, measured)

        switch target {
        case .header:
            if abs(topHeaderHeight - normalized) > 0.5 {
                topHeaderHeight = normalized
            }
        case .modeAndTab:
            if abs(modeAndTabSectionHeight - normalized) > 0.5 {
                modeAndTabSectionHeight = normalized
            }
        case .footer:
            if abs(footerBarHeight - normalized) > 0.5 {
                footerBarHeight = normalized
            }
        }
    }

    func updateCurrentTabContentHeight(_ measured: CGFloat, for tab: RootTab) {
        guard tab == self.rootViewModel.currentTab else { return }

        let normalized = max(1, measured)
        guard abs(self.currentTabContentHeight - normalized) > 0.5 else { return }

        self.currentTabContentHeight = normalized
    }

    func publishPreferredPanelHeight() {
        guard self.hasResolvedCurrentTabLayout else { return }
        popoverLayoutModel.requestPanelHeight(max(1, self.resolvedPanelHeight.rounded(.up)))
    }
}
