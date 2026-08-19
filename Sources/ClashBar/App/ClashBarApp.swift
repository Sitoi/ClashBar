import AppKit
import SwiftUI

@main
struct ClashBarApp: App {
    @NSApplicationDelegateAdaptor(ClashBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                ClashBarCommands(
                    session: self.appDelegate.appViewModel,
                    showSettingsPanel: { self.appDelegate.showSettingsPanel() })
            }
    }
}

private struct ClashBarCommands: Commands {
    @ObservedObject private var session: AppViewModel
    @ObservedObject private var remoteMachineStore: RemoteMachineStore
    private let showSettingsPanel: () -> Void

    init(session: AppViewModel, showSettingsPanel: @escaping () -> Void) {
        self.session = session
        self.remoteMachineStore = session.remoteMachineStore
        self.showSettingsPanel = showSettingsPanel
    }

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(self.tr("ui.tab.system"), action: self.showSettingsPanel)
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu(self.tr("ui.menu.quick")) {
            Button(self.tr("ui.quick.system_proxy")) {
                Task { await self.session.toggleSystemProxy(!self.session.isSystemProxyEnabled) }
            }
            .keyboardShortcut("S", modifiers: .command)

            Button(self.session.isTunEnabled ? self.tr("ui.action.disable_tun") : self
                .tr("ui.action.enable_tun"))
            {
                self.toggleTunMode()
            }
            .keyboardShortcut("E", modifiers: .command)
            .disabled(!self.isTunToggleEnabled)

            Divider()

            // ponytail: ⌘C shadows Edit > Copy while the app is frontmost; ⌘⇧C if that bites
            Button(self.tr("ui.quick.copy_terminal"), action: self.copyLocalProxyCommand)
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
            .disabled(!self.session.isPrimaryCoreActionEnabled || self.isRemoteTarget)

            Button(self.tr("ui.action.stop")) {
                Task { await self.session.stopCore() }
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(self.isRemoteTarget || self.session.isCoreActionProcessing)
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

    private var isRemoteTarget: Bool {
        !self.remoteMachineStore.activeTarget.isLocal
    }

    private var isTunToggleEnabled: Bool {
        (self.isRemoteTarget || self.session.isRuntimeRunning) && !self.session.isCoreActionProcessing &&
            !self.session.isTunSyncing
    }

    private func copyLocalProxyCommand() {
        let copied = self.session.copyLocalProxyCommand()
        self.session.statusItemBanner = StatusItemBanner(
            style: copied ? .success : .error,
            symbolName: copied ? "doc.on.doc.fill" : "exclamationmark.triangle.fill",
            title: self.tr("ui.banner.quick_action.title"),
            primaryDetail: self.tr(copied ? "ui.banner.copy_proxy.success" : "ui.banner.copy_proxy.failure"),
            secondaryDetail: copied ? self.session.localProxyCommandTargetDisplay() : nil)
    }

    private func toggleTunMode() {
        let enabled = !self.session.isTunEnabled
        Task {
            let succeeded = await self.session.toggleTunMode(enabled)
            self.session.statusItemBanner = StatusItemBanner(
                style: succeeded ? .success : .error,
                symbolName: succeeded ? "shield.lefthalf.filled" : "exclamationmark.triangle.fill",
                title: self.tr("ui.banner.quick_action.title"),
                primaryDetail: self.tr(succeeded
                    ? (enabled ? "ui.banner.tun.enabled" : "ui.banner.tun.disabled")
                    : "ui.banner.tun.failure"),
                secondaryDetail: succeeded ? nil : self.tr("ui.banner.check_logs"))
        }
    }
}
