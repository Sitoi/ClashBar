import Foundation

@MainActor
final class AppCoordinator {
    let appViewModel: AppViewModel

    init(appViewModel: AppViewModel = AppViewModel()) {
        self.appViewModel = appViewModel
    }
}
