import Foundation

struct PresentConnectionsUseCase {
    func execute(
        connections: [ConnectionSummary],
        filterText: String,
        transportFilter: ConnectionsTransportFilter,
        sortOption: ConnectionsSortOption,
        searchText: (ConnectionSummary) -> String) -> [ConnectionSummary]
    {
        let source = connections.prefix(120)
        let keyword = filterText.trimmed

        let filtered: [ConnectionSummary] = if keyword.isEmpty, transportFilter == .all {
            Array(source)
        } else {
            source.filter { connection in
                guard transportFilter.matches(connection.metadata?.network) else { return false }
                guard keyword.isEmpty || searchText(connection).localizedStandardContains(keyword) else {
                    return false
                }
                return true
            }
        }

        return self.sortedConnections(filtered, sortOption: sortOption)
    }

    private func sortedConnections(
        _ source: [ConnectionSummary],
        sortOption: ConnectionsSortOption) -> [ConnectionSummary]
    {
        switch sortOption {
        case .default:
            source
        case .newest:
            self.connectionsSortedByTimestamp(source, descending: true)
        case .oldest:
            self.connectionsSortedByTimestamp(source, descending: false)
        case .uploadDesc:
            self.connectionsSortedByTraffic(source) { $0.upload ?? 0 }
        case .downloadDesc:
            self.connectionsSortedByTraffic(source) { $0.download ?? 0 }
        case .totalDesc:
            self.connectionsSortedByTraffic(source) { ($0.upload ?? 0) + ($0.download ?? 0) }
        }
    }

    private func connectionsSortedByTimestamp(
        _ source: [ConnectionSummary],
        descending: Bool) -> [ConnectionSummary]
    {
        let fallback: TimeInterval = descending ? -1 : .greatestFiniteMagnitude
        return source.sorted { lhs, rhs in
            let left = lhs.startTimestamp ?? fallback
            let right = rhs.startTimestamp ?? fallback
            if left != right {
                return descending ? (left > right) : (left < right)
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private func connectionsSortedByTraffic(
        _ source: [ConnectionSummary],
        _ metric: (ConnectionSummary) -> Int64) -> [ConnectionSummary]
    {
        source.sorted { lhs, rhs in
            let left = metric(lhs)
            let right = metric(rhs)
            if left != right {
                return left > right
            }
            return (lhs.startTimestamp ?? -1) > (rhs.startTimestamp ?? -1)
        }
    }
}
