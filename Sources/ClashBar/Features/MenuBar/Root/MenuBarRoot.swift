import AppKit
import SwiftUI

enum RootTab: CaseIterable, Hashable {
    case proxy
    case rules
    case activity
    case logs
    case system

    var titleKey: String {
        switch self {
        case .proxy: return "ui.tab.proxy"
        case .rules: return "ui.tab.rules"
        case .activity: return "ui.tab.activity"
        case .logs: return "ui.tab.logs"
        case .system: return "ui.tab.system"
        }
    }
}

enum LogLevelFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: return "ui.log_filter.all"
        case .info: return "ui.log_filter.info"
        case .warning: return "ui.log_filter.warning"
        case .error: return "ui.log_filter.error"
        }
    }

    func matches(level: String) -> Bool {
        switch self {
        case .all:
            return true
        case .info:
            return level == "INFO"
        case .warning:
            return level == "WARNING"
        case .error:
            return level == "ERROR"
        }
    }
}

enum LogSourceFilter: String, CaseIterable, Identifiable {
    case all
    case clashbar
    case mihomo

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all:
            return "ui.log_source.all"
        case .clashbar:
            return "ui.log_source.clashbar"
        case .mihomo:
            return "ui.log_source.mihomo"
        }
    }

    func matches(source: AppLogSource) -> Bool {
        switch self {
        case .all:
            return true
        case .clashbar:
            return source == .clashbar
        case .mihomo:
            return source == .mihomo
        }
    }
}

struct MenuBarRoot: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var popoverLayoutModel: PopoverLayoutModel

    @State var currentTab: RootTab = .proxy
    @State var switchingMode: CoreMode?
    @State var hoveringCopyRow = false
    @State var hoveredRuleIndex: Int?
    @State var networkFilterText: String = ""
    @State var hoveredConnectionID: String?
    @State var hoveredProxyGroupName: String?
    @State var hoveredProxyProviderName: String?
    @State var hoveredMode: CoreMode?
    @State var selectedLogSources: Set<AppLogSource> = Set(AppLogSource.allCases)
    @State var selectedLogLevels: Set<LogLevelFilter> = [.info, .warning, .error]
    @State var logSearchText: String = ""
    @State var topHeaderHeight: CGFloat = 0
    @State var modeAndTabSectionHeight: CGFloat = 0
    @State var footerBarHeight: CGFloat = 0
    @State var tabContentHeights: [RootTab: CGFloat] = [:]

    let panelWidth: CGFloat = 360
    let fallbackTabContentHeight: CGFloat = 380

    var contentWidth: CGFloat {
        panelWidth - (MenuBarLayoutTokens.hPage * 2)
    }

    var language: AppLanguage { appState.uiLanguage }
    var tabContentTopInset: CGFloat { MenuBarLayoutTokens.vDense }

    func tr(_ key: String) -> String {
        L10n.t(key, language: language)
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.t(key, language: language, args: args)
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeader
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .header) }

            modeAndTabSection
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .modeAndTab) }

            ScrollView(.vertical) {
                tabScrollContent(for: currentTab)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: tabScrollAreaHeight)

            footerBar
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .footer) }
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(MenuBarLayoutTokens.hPage)
        .frame(width: panelWidth, height: resolvedPanelHeight)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            let restoredTab = rootTab(for: appState.activeMenuTab)
            if currentTab != restoredTab {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentTab = restoredTab
                }
            }
            appState.setActiveMenuTab(menuPanelTabHint(for: currentTab))
            publishPreferredPanelHeight()
        }
        .onChange(of: currentTab) { _, tab in
            appState.setActiveMenuTab(menuPanelTabHint(for: tab))
        }
        .onChange(of: appState.activeMenuTab) { _, hint in
            let tab = rootTab(for: hint)
            guard currentTab != tab else { return }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                currentTab = tab
            }
        }
        .onChange(of: resolvedPanelHeight) { _, _ in
            publishPreferredPanelHeight()
        }
        .onChange(of: popoverLayoutModel.maxPanelHeight) { _, _ in
            publishPreferredPanelHeight()
        }
    }

    @ViewBuilder
    func tabBody(for tab: RootTab) -> some View {
        switch tab {
        case .proxy:
            proxyTabBody
        case .rules:
            rulesTabBody
        case .activity:
            activityTabBody
        case .logs:
            logsTabBody
        case .system:
            systemTabBody
        }
    }

    func tabScrollContent(for tab: RootTab) -> some View {
        tabBody(for: tab)
            .padding(.top, tabContentTopInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .reportHeight { updateTabContentHeight($0, for: tab) }
    }
    var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(nativeSeparator, lineWidth: 0.8)
            }
            .shadow(color: Color(nsColor: .shadowColor).opacity(0.28), radius: 18, x: 0, y: 10)
    }
}
