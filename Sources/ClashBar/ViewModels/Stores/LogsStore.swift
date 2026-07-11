import Combine
import Foundation

@MainActor
final class LogsStore: ObservableObject {
    var errorLogs: [AppErrorLogEntry] = [] {
        willSet { self.publishChangeIfNeeded(current: self.errorLogs, next: newValue) }
    }

    var startupErrorMessage: String? {
        willSet { self.publishChangeIfNeeded(current: self.startupErrorMessage, next: newValue) }
    }

    private func publishChangeIfNeeded<Value: Equatable>(current: Value, next: Value) {
        guard current != next else { return }
        self.objectWillChange.send()
    }
}
