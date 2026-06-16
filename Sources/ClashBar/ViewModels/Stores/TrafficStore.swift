import Foundation

@MainActor
final class TrafficStore {
    weak var viewModel: AppViewModel?

    var traffic: TrafficSnapshot = .init(up: 0, down: 0) {
        willSet { self.viewModel?.objectWillChange.send() }
        didSet { self.viewModel?.refreshMenuBarDisplaySnapshotIfNeeded() }
    }

    var memory: MemorySnapshot = .init(inuse: 0) {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var displayUpTotal: Int64 = 0 {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var displayDownTotal: Int64 = 0 {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var trafficHistoryUp: [Int64] = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }

    var trafficHistoryDown: [Int64] = [] {
        willSet { self.viewModel?.objectWillChange.send() }
    }
}
