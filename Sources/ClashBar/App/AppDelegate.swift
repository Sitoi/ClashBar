import AppKit

@MainActor
final class ClashBarAppDelegate: NSObject, NSApplicationDelegate {
    let container = AppCoordinator()
    private var statusItemController: StatusItemController?

    var appViewModel: AppViewModel {
        self.container.appViewModel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = BrandIcon.image {
            NSApp.applicationIconImage = image
        }
        NSApp.setActivationPolicy(.accessory)
        self.statusItemController = StatusItemController(appViewModel: self.appViewModel)
        self.appViewModel.presentInitialNoCoreSetupGuideIfNeeded()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        self.appViewModel.handleApplicationDidBecomeActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.appViewModel.shutdownForTermination()
        self.statusItemController?.shutdown()
        self.statusItemController = nil
    }
}
