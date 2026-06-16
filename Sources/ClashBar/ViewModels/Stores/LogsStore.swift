import Foundation

@MainActor
final class LogsStore {
    weak var viewModel: AppViewModel?

    var errorLogs: [AppErrorLogEntry] = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var startupErrorMessage: String? {
        willSet { self.viewModel?.objectWillChange.send() }
    }
}
