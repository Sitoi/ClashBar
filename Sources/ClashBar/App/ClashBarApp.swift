import AppKit
import SwiftUI

@main
struct ClashBarApp: App {
    @NSApplicationDelegateAdaptor(ClashBarAppDelegate.self) private var appDelegate

    private var session: AppViewModel {
        self.appDelegate.appViewModel
    }

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(self.tr("ui.tab.system")) {
                        self.appDelegate.showSettingsPanel()
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }

                CommandMenu("Core") {
                    Button(self.session.primaryCoreActionLabel) {
                        Task { await self.session.performPrimaryCoreAction() }
                    }
                    .keyboardShortcut("R", modifiers: [.command, .shift])
                    .disabled(!self.session.isPrimaryCoreActionEnabled || self.session.isRemoteTarget)

                    Button(self.tr("ui.action.stop")) {
                        Task { await self.session.stopCore() }
                    }
                    .keyboardShortcut(".", modifiers: [.command, .shift])
                    .disabled(self.session.isRemoteTarget || self.session.isCoreActionProcessing)

                    Divider()

                    Button(self.session.isTunEnabled ? self.tr("ui.action.disable_tun") : self
                        .tr("ui.action.enable_tun"))
                    {
                        Task { await self.session.toggleTunMode(!self.session.isTunEnabled) }
                    }
                    .keyboardShortcut("T", modifiers: [.command, .option])
                    .disabled(!self.session.isTunToggleEnabled)
                }

                CommandMenu("Panel") {
                    ForEach(Self.panelShortcuts, id: \.tab) { entry in
                        Button(self.tr(entry.key)) { self.session.setActiveMenuTab(entry.tab) }
                            .keyboardShortcut(entry.shortcut, modifiers: [.command, .option])
                    }
                    Button(self.tr("ui.tab.system")) { self.session.setActiveMenuTab(.system) }
                        .keyboardShortcut("5", modifiers: [.command, .option])
                }

                CommandMenu("Actions") {
                    Button(self.tr("ui.action.refresh")) {
                        Task { await self.session.refreshActiveTab() }
                    }
                    .keyboardShortcut("K", modifiers: [.command, .shift])

                    Button(self.tr("ui.quick.copy_terminal")) { self.session.copyProxyCommand() }
                        .keyboardShortcut("C", modifiers: [.command, .option, .shift])

                    Button(self.tr("ui.action.copy_all_logs")) { self.session.copyAllLogs() }
                        .keyboardShortcut("L", modifiers: [.command, .option, .shift])

                    Button(self.tr("ui.action.clear_all_logs")) { self.session.clearAllLogs() }
                        .keyboardShortcut(.delete, modifiers: [.command, .option, .shift])
                        .disabled(self.session.errorLogs.isEmpty)
                }
            }
    }

    private static let panelShortcuts: [(tab: RootTab, key: String, shortcut: KeyEquivalent)] = [
        (.proxy, "ui.tab.proxy", "1"),
        (.rules, "ui.tab.rules", "2"),
        (.connections, "ui.tab.connections", "3"),
        (.logs, "ui.tab.logs", "4"),
    ]

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.session.uiLanguage)
    }
}
