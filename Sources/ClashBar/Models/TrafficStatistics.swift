import Foundation

enum TrafficStatisticsDimension: String, CaseIterable, Identifiable, Sendable {
    case node
    case application
    case domain

    var id: String { self.rawValue }

    var titleKey: String {
        switch self {
        case .node: "ui.statistics.dimension.node"
        case .application: "ui.statistics.dimension.application"
        case .domain: "ui.statistics.dimension.domain"
        }
    }
}

struct TrafficStatisticsEntry: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let upload: Int64
    let download: Int64

    var total: Int64 { self.upload + self.download }
}

struct TrafficStatisticsSnapshot: Equatable, Sendable {
    let dimension: TrafficStatisticsDimension
    let entries: [TrafficStatisticsEntry]

    static let empty = TrafficStatisticsSnapshot(dimension: .node, entries: [])
}

struct ConnectionStatisticsUpdate: Sendable {
    let totalCount: Int
    let connections: [ConnectionSummary]?
    let statistics: TrafficStatisticsSnapshot?
}
