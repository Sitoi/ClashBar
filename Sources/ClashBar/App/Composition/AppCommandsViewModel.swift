import Foundation

@MainActor
final class AppCommandsViewModel {
    private let session: AppSession

    init(session: AppSession) {
        self.session = session
    }

    var primaryCoreActionLabel: String {
        self.session.primaryCoreActionLabel
    }

    var isPrimaryCoreActionEnabled: Bool {
        self.session.isPrimaryCoreActionEnabled && !self.session.isRemoteTarget
    }

    var isCoreActionProcessing: Bool {
        self.session.isCoreActionProcessing
    }

    var isStopCoreEnabled: Bool {
        !self.session.isRemoteTarget && !self.session.isCoreActionProcessing
    }

    var isTunEnabled: Bool {
        self.session.isTunEnabled
    }

    var isTunToggleEnabled: Bool {
        self.session.isTunToggleEnabled
    }

    var hasLogs: Bool {
        !self.session.errorLogs.isEmpty
    }

    var uiLanguage: AppLanguage {
        self.session.uiLanguage
    }

    func performPrimaryCoreAction() async {
        await self.session.performPrimaryCoreAction()
    }

    func stopCore() async {
        await self.session.stopCore()
    }

    func toggleTunMode() async {
        await self.session.toggleTunMode(!self.session.isTunEnabled)
    }

    func setActiveMenuTab(_ tab: RootTab) {
        self.session.setActiveMenuTab(tab)
    }

    func refreshActiveTab() async {
        await self.session.refreshActiveTab()
    }

    func copyProxyCommand() {
        self.session.copyProxyCommand()
    }

    func copyAllLogs() {
        self.session.copyAllLogs()
    }

    func clearAllLogs() {
        self.session.clearAllLogs()
    }
}
