import AppKit
import SwiftUI

@main
struct ClashBarApp: App {
    @NSApplicationDelegateAdaptor(ClashBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                AppCommands(session: self.appDelegate.appViewModel, appDelegate: self.appDelegate)
            }
    }
}

/// Menu commands have to live in a `Commands` type that observes the session. `App` itself has
/// no observation, so building them inline froze every `.disabled(...)` and label at their
/// launch-time values — the core always looked stopped and ⌘E stayed permanently disabled.
private struct AppCommands: Commands {
    @ObservedObject var session: AppViewModel
    let appDelegate: ClashBarAppDelegate

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(self.tr("ui.tab.system")) {
                self.appDelegate.showSettingsPanel()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu(self.tr("ui.menu.quick")) {
            Button(self.tr("ui.quick.system_proxy")) {
                Task { await self.session.toggleSystemProxy(!self.session.isSystemProxyEnabled) }
            }
            .keyboardShortcut("S", modifiers: .command)

            Button(self.session.isTunEnabled ? self.tr("ui.action.disable_tun") : self.tr("ui.action.enable_tun")) {
                Task { await self.session.toggleTunMode(!self.session.isTunEnabled) }
            }
            .keyboardShortcut("E", modifiers: .command)
            .disabled(!self.session.isTunToggleEnabled)

            Divider()

            // ponytail: ⌘C shadows Edit > Copy while the app is frontmost; ⌘⇧C if that bites
            Button(self.tr("ui.quick.copy_terminal")) { self.session.copyLocalProxyCommand() }
                .keyboardShortcut("C", modifiers: .command)

            Button(self.tr("ui.quick.copy_terminal_current_endpoint")) {
                self.session.copyManagedEndpointProxyCommand()
            }
            .keyboardShortcut("C", modifiers: [.command, .option])

            Divider()

            Button(self.tr("ui.action.reload_config")) {
                Task { await self.session.reloadConfig() }
            }
            .keyboardShortcut("R", modifiers: .command)

            Divider()

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
        }

        CommandMenu("Panel") {
            ForEach(Self.panelShortcuts, id: \.tab) { entry in
                Button(self.tr(entry.key)) { self.session.setActiveMenuTab(entry.tab) }
                    .keyboardShortcut(entry.shortcut, modifiers: [.command, .option])
            }
            Button(self.tr("ui.tab.system")) { self.session.setActiveMenuTab(.system) }
                .keyboardShortcut("5", modifiers: [.command, .option])
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
