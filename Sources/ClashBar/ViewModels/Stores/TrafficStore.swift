import Combine
import Foundation

@MainActor
final class TrafficStore: ObservableObject {
    let trafficDidChange = PassthroughSubject<TrafficSnapshot, Never>()

    var traffic: TrafficSnapshot = .init(up: 0, down: 0) {
        willSet {
            guard self.traffic != newValue else { return }
            self.objectWillChange.send()
            self.trafficDidChange.send(newValue)
        }
    }

    var memory: MemorySnapshot = .init(inuse: 0) {
        willSet { self.publishChangeIfNeeded(current: self.memory, next: newValue) }
    }

    var displayUpTotal: Int64 = 0 {
        willSet { self.publishChangeIfNeeded(current: self.displayUpTotal, next: newValue) }
    }

    var displayDownTotal: Int64 = 0 {
        willSet { self.publishChangeIfNeeded(current: self.displayDownTotal, next: newValue) }
    }

    var trafficHistoryUp: [Int64] = [] {
        willSet { self.publishChangeIfNeeded(current: self.trafficHistoryUp, next: newValue) }
    }

    var trafficHistoryDown: [Int64] = [] {
        willSet { self.publishChangeIfNeeded(current: self.trafficHistoryDown, next: newValue) }
    }

    private func publishChangeIfNeeded<Value: Equatable>(current: Value, next: Value) {
        guard current != next else { return }
        self.objectWillChange.send()
    }
}
