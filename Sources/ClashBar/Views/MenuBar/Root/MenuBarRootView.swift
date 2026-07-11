import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

enum RootTab: String, CaseIterable, Hashable {
    case proxy
    case rules
    case connections
    case logs
    case system

    var titleKey: String {
        switch self {
        case .proxy: "ui.tab.proxy"
        case .rules: "ui.tab.rules"
        case .connections: "ui.tab.connections"
        case .logs: "ui.tab.logs"
        case .system: "ui.tab.system"
        }
    }

    var symbolName: String {
        switch self {
        case .proxy: "square.grid.2x2.fill"
        case .rules: "arrow.left.arrow.right"
        case .connections: "link"
        case .logs: "doc.fill"
        case .system: "gearshape.fill"
        }
    }
}

enum LogLevelFilter: Hashable, CaseIterable {
    case info
    case warning
    case error

    var titleKey: String {
        switch self {
        case .info: "ui.log_filter.info"
        case .warning: "ui.log_filter.warning"
        case .error: "ui.log_filter.error"
        }
    }
}

struct MenuBarRootView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var proxyStore: ProxyStore
    @EnvironmentObject var remoteMachineStore: RemoteMachineStore
    @EnvironmentObject var popoverLayoutModel: PopoverLayoutModel
    @Environment(\.colorScheme) var colorScheme

    @StateObject var rootViewModel = ProxyGroupsViewModel()
    @Namespace var segmentedSelectionNamespace

    @State var switchingMode: CoreMode?
    @State var isSwitchingMachine = false
    @State var showRemoteMachineManager = false
    @State var hoveredMode: CoreMode?
    @State var hoveredTab: RootTab?
    @State var topHeaderHeight: CGFloat = 0
    @State var modeAndTabSectionHeight: CGFloat = 0
    @State var footerBarHeight: CGFloat = 0
    @State var currentTabContentHeight: CGFloat = 0
    @AppStorage("clashbar.proxy.group.hide_hidden") var hideHiddenProxyGroups: Bool = true
    @AppStorage("clashbar.proxy.group.sort_nodes_by_latency") var sortGroupNodesByLatency: Bool =
        false

    var contentWidth: CGFloat {
        T.panelWidth - (T.space8 * 2)
    }

    func setCurrentTabWithoutAnimation(_ tab: RootTab) {
        guard self.rootViewModel.currentTab != tab else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.rootViewModel.syncCurrentTab(tab)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.panelContent
            Spacer(minLength: 0)
        }
        .frame(width: T.panelWidth, alignment: .topLeading)
    }

    private var panelSections: some View {
        VStack(spacing: 0) {
            MenuBarHeaderView(
                showRemoteMachineManager: self.$showRemoteMachineManager,
                isSwitchingMachine: self.$isSwitchingMachine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .header) }

            modeAndTabSection
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .modeAndTab) }

            ScrollView(.vertical) {
                self.measuredTabContent(for: self.rootViewModel.currentTab)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: tabScrollAreaHeight, alignment: .top)

            footerBar
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .footer) }
        }
    }

    private var styledPanelContent: some View {
        self.panelSections
            .frame(width: self.contentWidth, alignment: .topLeading)
            .padding(.horizontal, T.space8)
            .frame(
                width: T.panelWidth,
                height: resolvedPanelHeight,
                alignment: .topLeading)
            .background(self.panelBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: T.panelCornerRadius, style: .continuous))
    }

    var panelContent: some View {
        self.styledPanelContent
            .onAppear {
                self.setCurrentTabWithoutAnimation(self.appViewModel.activeMenuTab)
                self.appViewModel.setActiveMenuTab(self.rootViewModel.currentTab)
                self.refreshDerivedData(for: self.rootViewModel.currentTab)
                self.rootViewModel.updateFilteredProxyGroups(
                    from: self.proxyStore.proxyGroups,
                    hideHiddenGroups: self.hideHiddenProxyGroups,
                    currentMode: self.appViewModel.currentMode)
                publishPreferredPanelHeight()
            }
            .onChange(of: self.rootViewModel.currentTab) { tab in
                self.currentTabContentHeight = 0
                self.appViewModel.setActiveMenuTab(tab)
                self.refreshDerivedData(for: tab)
            }
            .onChange(of: self.appViewModel.activeMenuTab) { tab in
                guard self.rootViewModel.currentTab != tab else { return }
                self.setCurrentTabWithoutAnimation(tab)
                self.currentTabContentHeight = 0
                self.refreshDerivedData(for: tab)
            }
            .onChange(of: resolvedPanelHeight) { _ in
                publishPreferredPanelHeight()
            }
            .onChange(of: self.popoverLayoutModel.maxPanelHeight) { _ in
                publishPreferredPanelHeight()
            }
            .onChange(of: self.proxyStore.proxyGroups) { newGroups in
                self.rootViewModel.updateFilteredProxyGroups(
                    from: newGroups,
                    hideHiddenGroups: self.hideHiddenProxyGroups,
                    currentMode: self.appViewModel.currentMode)
            }
            .onChange(of: self.hideHiddenProxyGroups) { newValue in
                self.rootViewModel.updateFilteredProxyGroups(
                    from: self.proxyStore.proxyGroups,
                    hideHiddenGroups: newValue,
                    currentMode: self.appViewModel.currentMode)
            }
            .onChange(of: self.appViewModel.currentMode) { newMode in
                self.rootViewModel.updateFilteredProxyGroups(
                    from: self.proxyStore.proxyGroups,
                    hideHiddenGroups: self.hideHiddenProxyGroups,
                    currentMode: newMode)
            }
    }

    @ViewBuilder
    func tabBody(for tab: RootTab) -> some View {
        switch tab {
        case .proxy:
            ProxyTabView(rootViewModel: self.rootViewModel)
        case .rules:
            RulesTabView()
        case .connections:
            ConnectionsTabView()
        case .logs:
            LogsTabView()
        case .system:
            SystemTabView()
        }
    }

    func tabUsesDynamicHeight(_ tab: RootTab) -> Bool {
        switch tab {
        case .proxy, .system:
            true
        case .rules, .connections, .logs:
            false
        }
    }

    @ViewBuilder
    func measuredTabContent(for tab: RootTab) -> some View {
        let content = self.tabContent(for: tab)
            .frame(maxWidth: .infinity, alignment: .leading)

        if self.tabUsesDynamicHeight(tab) {
            content.reportHeight { updateCurrentTabContentHeight($0, for: tab) }
        } else {
            content
        }
    }

    @ViewBuilder
    func tabContent(for tab: RootTab) -> some View {
        let content = self.tabBody(for: tab)
            .padding(.top, T.space2)

        if self.tabUsesDynamicHeight(tab) {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }

    var panelBackground: some View {
        AppMaterialSurface(
            cornerRadius: T.panelCornerRadius,
            fallbackStyle: .material(.regularMaterial),
            stroke: nativeSeparator)
            .shadow(
                color: self.nativeShadow.opacity(
                    T.Shadow.standard.opacity),
                radius: T.Shadow.standard.radius,
                x: T.Shadow.standard.x,
                y: T.Shadow.standard.y)
    }

    func refreshDerivedData(for tab: RootTab) {
        switch tab {
        case .proxy:
            Task { await self.appViewModel.refreshSystemProxyHelperRuntimeSnapshot() }
        case .system, .rules, .connections, .logs:
            break
        }
    }
}
