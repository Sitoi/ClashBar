import Foundation

@MainActor
final class DependencyContainer {
    let appSession: AppSession

    init(appSession: AppSession = AppSession()) {
        self.appSession = appSession
    }
}
