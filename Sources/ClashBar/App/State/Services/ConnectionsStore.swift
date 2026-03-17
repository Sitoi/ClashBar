import Foundation

@MainActor
final class ConnectionsStore: ObservableObject {
    @Published var connections: [ConnectionSummary] = []
    @Published var connectionsCount: Int = 0
}
