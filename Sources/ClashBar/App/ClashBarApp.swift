import AppKit
import SwiftUI

@main
struct ClashBarApp: App {
    @NSApplicationDelegateAdaptor(ClashBarAppDelegate.self) private var appDelegate

    private var commandsViewModel: AppCommandsViewModel {
        AppCommandsViewModel(session: self.appDelegate.appSession)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("Core") {
                Button(self.commandsViewModel.primaryCoreActionLabel) {
                    Task { await self.commandsViewModel.performPrimaryCoreAction() }
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                .disabled(!self.commandsViewModel.isPrimaryCoreActionEnabled)

                Button(self.tr("ui.action.stop")) {
                    Task { await self.commandsViewModel.stopCore() }
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(self.commandsViewModel.isCoreActionProcessing)

                Divider()

                Button(self.commandsViewModel.isTunEnabled ? self.tr("ui.action.disable_tun") : self
                    .tr("ui.action.enable_tun"))
                {
                    Task { await self.commandsViewModel.toggleTunMode() }
                }
                .keyboardShortcut("T", modifiers: [.command, .option])
                .disabled(!self.commandsViewModel.isTunToggleEnabled)
            }

            CommandMenu("Panel") {
                Button(self.tr("ui.tab.proxy")) {
                    self.commandsViewModel.setActiveMenuTab(.proxy)
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(self.tr("ui.tab.rules")) {
                    self.commandsViewModel.setActiveMenuTab(.rules)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button(self.tr("ui.tab.connections")) {
                    self.commandsViewModel.setActiveMenuTab(.connections)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Button(self.tr("ui.tab.logs")) {
                    self.commandsViewModel.setActiveMenuTab(.logs)
                }
                .keyboardShortcut("4", modifiers: [.command, .option])

                Button(self.tr("ui.tab.system")) {
                    self.commandsViewModel.setActiveMenuTab(.system)
                }
                .keyboardShortcut("5", modifiers: [.command, .option])

                Button(self.tr("ui.tab.system")) {
                    self.commandsViewModel.setActiveMenuTab(.system)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu("Actions") {
                Button(self.tr("ui.action.refresh")) {
                    Task { await self.commandsViewModel.refreshActiveTab() }
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

                Button(self.tr("ui.quick.copy_terminal")) {
                    self.commandsViewModel.copyProxyCommand()
                }
                .keyboardShortcut("C", modifiers: [.command, .option, .shift])

                Button(self.tr("ui.action.copy_all_logs")) {
                    self.commandsViewModel.copyAllLogs()
                }
                .keyboardShortcut("L", modifiers: [.command, .option, .shift])

                Button(self.tr("ui.action.clear_all_logs")) {
                    self.commandsViewModel.clearAllLogs()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option, .shift])
                .disabled(!self.commandsViewModel.hasLogs)
            }
        }
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.commandsViewModel.uiLanguage)
    }
}

@MainActor
final class ClashBarAppDelegate: NSObject, NSApplicationDelegate {
    let container = DependencyContainer()
    private var statusItemController: StatusItemController?

    var appSession: AppSession {
        self.container.appSession
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = BrandIcon.image {
            NSApp.applicationIconImage = image
        }
        NSApp.setActivationPolicy(.accessory)
        self.statusItemController = StatusItemController(appSession: self.appSession)
        self.appSession.presentInitialNoCoreSetupGuideIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.appSession.shutdownForTermination()
        self.statusItemController?.shutdown()
        self.statusItemController = nil
    }
}
