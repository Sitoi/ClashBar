import Foundation
import SwiftUI

enum ConnectionsTransportFilter: String, CaseIterable, Identifiable {
    case all
    case tcp
    case udp
    case other

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .all:
            "ui.network.filter.transport.all"
        case .tcp:
            "ui.network.filter.transport.tcp"
        case .udp:
            "ui.network.filter.transport.udp"
        case .other:
            "ui.network.filter.transport.other"
        }
    }

    func matches(_ network: String?) -> Bool {
        let normalized = network.trimmedOrEmpty.lowercased()

        switch self {
        case .all:
            return true
        case .tcp:
            return normalized == "tcp"
        case .udp:
            return normalized == "udp"
        case .other:
            return !normalized.isEmpty && normalized != "tcp" && normalized != "udp"
        }
    }
}

enum ConnectionsSortOption: String, CaseIterable, Identifiable {
    case `default`
    case newest
    case oldest
    case uploadDesc
    case downloadDesc
    case totalDesc

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .default:
            "ui.network.sort.default"
        case .newest:
            "ui.network.sort.newest"
        case .oldest:
            "ui.network.sort.oldest"
        case .uploadDesc:
            "ui.network.sort.upload_desc"
        case .downloadDesc:
            "ui.network.sort.download_desc"
        case .totalDesc:
            "ui.network.sort.total_desc"
        }
    }
}

@MainActor
final class ConnectionsTabViewModel: ObservableObject {
    private let presentConnectionsUseCase: PresentConnectionsUseCase

    @Published var filterText: String = ""
    @Published var transportFilter: ConnectionsTransportFilter = .all
    @Published var sortOption: ConnectionsSortOption = .default
    @Published var hoveredConnectionID: String?
    @Published private(set) var visibleConnections: [ConnectionSummary] = []

    init(presentConnectionsUseCase: PresentConnectionsUseCase = PresentConnectionsUseCase()) {
        self.presentConnectionsUseCase = presentConnectionsUseCase
    }

    func updateVisibleConnections(
        from connections: [ConnectionSummary],
        searchText: (ConnectionSummary) -> String)
    {
        let nextConnections = self.presentConnectionsUseCase.execute(
            connections: connections,
            filterText: self.filterText,
            transportFilter: self.transportFilter,
            sortOption: self.sortOption,
            searchText: searchText)
        guard nextConnections != self.visibleConnections else { return }
        self.visibleConnections = nextConnections
    }
}
