import Foundation

@MainActor
final class ConnectionsStore: ObservableObject {
    @Published var connections: [ConnectionSummary] = []
    @Published var connectionsCount: Int = 0
    @Published var showsStatistics = false
    @Published var statisticsDimension: TrafficStatisticsDimension = .node
    @Published var statistics: TrafficStatisticsSnapshot = .empty
}
