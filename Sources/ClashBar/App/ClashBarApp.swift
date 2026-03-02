import AppKit
import SwiftUI

@main
struct ClashBarApp: App {
    @NSApplicationDelegateAdaptor(ClashBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("Core") {
                Button(appDelegate.appState.primaryCoreActionLabel) {
                    Task { await appDelegate.appState.performPrimaryCoreAction() }
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                .disabled(!appDelegate.appState.isPrimaryCoreActionEnabled)

                Button(tr("ui.action.stop")) {
                    Task { await appDelegate.appState.stopCore() }
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(appDelegate.appState.isCoreActionProcessing)

                Divider()

                Button(appDelegate.appState.isTunEnabled ? tr("ui.action.disable_tun") : tr("ui.action.enable_tun")) {
                    let toggled = !appDelegate.appState.isTunEnabled
                    Task { await appDelegate.appState.toggleTunMode(toggled) }
                }
                .keyboardShortcut("T", modifiers: [.command, .option])
                .disabled(!appDelegate.appState.isTunToggleEnabled)
            }

            CommandMenu("Panel") {
                Button(tr("ui.tab.proxy")) {
                    appDelegate.appState.setActiveMenuTab(.proxy)
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(tr("ui.tab.rules")) {
                    appDelegate.appState.setActiveMenuTab(.rules)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button(tr("ui.tab.activity")) {
                    appDelegate.appState.setActiveMenuTab(.activity)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Button(tr("ui.tab.logs")) {
                    appDelegate.appState.setActiveMenuTab(.logs)
                }
                .keyboardShortcut("4", modifiers: [.command, .option])

                Button(tr("ui.tab.system")) {
                    appDelegate.appState.setActiveMenuTab(.system)
                }
                .keyboardShortcut("5", modifiers: [.command, .option])
            }

            CommandMenu("Actions") {
                Button(tr("ui.action.refresh")) {
                    Task { await appDelegate.appState.refreshActiveTab() }
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])

                Button(tr("ui.quick.copy_terminal")) {
                    appDelegate.appState.copyProxyCommand()
                }
                .keyboardShortcut("C", modifiers: [.command, .option, .shift])

                Button(tr("ui.action.copy_all_logs")) {
                    appDelegate.appState.copyAllLogs()
                }
                .keyboardShortcut("L", modifiers: [.command, .option, .shift])

                Button(tr("ui.action.clear_all_logs")) {
                    appDelegate.appState.clearAllLogs()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option, .shift])
                .disabled(appDelegate.appState.errorLogs.isEmpty)
            }
        }
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: appDelegate.appState.uiLanguage)
    }
}

@MainActor
final class ClashBarAppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = BrandIcon.image {
            NSApp.applicationIconImage = image
        }
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(appState: appState)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdownForTermination()
        statusItemController?.shutdown()
        statusItemController = nil
    }
}
