import Foundation

// MARK: - LogsStore

/// Owns the in-memory log entries shown in the Logs tab.
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
