import Foundation

actor ConnectionStatisticsService {
    private struct Counters {
        let upload: Int64
        let download: Int64
    }

    private let decoder = JSONDecoder()
    private var activeConnections: [String: Counters] = [:]
    private var nodeTotals: [String: TrafficStatisticsEntry] = [:]
    private var applicationTotals: [String: TrafficStatisticsEntry] = [:]
    private var domainTotals: [String: TrafficStatisticsEntry] = [:]
    private var hasBaseline = false

    func process(
        _ payload: Data,
        includeConnections: Bool,
        statisticsDimension: TrafficStatisticsDimension?) throws -> ConnectionStatisticsUpdate
    {
        let snapshot = try self.decoder.decode(ConnectionsSnapshot.self, from: payload)
        var nextActiveConnections: [String: Counters] = [:]
        nextActiveConnections.reserveCapacity(snapshot.totalCount)

        for connection in snapshot.connections {
            let current = Counters(upload: max(0, connection.upload ?? 0), download: max(0, connection.download ?? 0))
            nextActiveConnections[connection.id] = current
            guard self.hasBaseline else { continue }

            let previous = self.activeConnections[connection.id]
            let upload = max(0, current.upload - (previous?.upload ?? 0))
            let download = max(0, current.download - (previous?.download ?? 0))
            guard upload > 0 || download > 0 else { continue }

            let node = connection.chains?.first ?? ""
            Self.accumulate(id: node, name: node, upload: upload, download: download, into: &self.nodeTotals)

            let metadata = connection.metadata
            let processPath = metadata?.processPath.trimmedNonEmpty
            let process = metadata?.process.trimmedNonEmpty
            let application = processPath ?? process ?? ""
            let applicationName = process ?? processPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
            Self.accumulate(
                id: application,
                name: applicationName,
                upload: upload,
                download: download,
                into: &self.applicationTotals)

            let domain = metadata?.host.trimmedNonEmpty
                ?? metadata?.sniffHost.trimmedNonEmpty
                ?? metadata?.destinationIP.trimmedNonEmpty
                ?? ""
            Self.accumulate(id: domain, name: domain, upload: upload, download: download, into: &self.domainTotals)
        }

        self.activeConnections = nextActiveConnections
        self.hasBaseline = true

        var connections: [ConnectionSummary]?
        if includeConnections {
            var visibleConnections = Array(snapshot.connections.prefix(ConnectionsSnapshot.retainedConnectionLimit))
            for index in visibleConnections.indices {
                visibleConnections[index].startTimestamp = ConnectionSummary.parseTimestamp(visibleConnections[index].start)
            }
            connections = visibleConnections
        }

        let statistics = statisticsDimension.map { dimension in
            let totals = switch dimension {
            case .node: self.nodeTotals
            case .application: self.applicationTotals
            case .domain: self.domainTotals
            }
            let entries = totals.values.sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.id < $1.id
            }
            return TrafficStatisticsSnapshot(dimension: dimension, entries: entries)
        }
        return ConnectionStatisticsUpdate(totalCount: snapshot.totalCount, connections: connections, statistics: statistics)
    }

    private static func accumulate(
        id: String,
        name: String,
        upload: Int64,
        download: Int64,
        into totals: inout [String: TrafficStatisticsEntry])
    {
        let previous = totals[id]
        totals[id] = TrafficStatisticsEntry(
            id: id,
            name: name,
            upload: (previous?.upload ?? 0) + upload,
            download: (previous?.download ?? 0) + download)
    }
}
