import Foundation

struct MeasureGroupLatencyUseCase {
    private let repository: any ProxyRepository

    init(repository: any ProxyRepository) {
        self.repository = repository
    }

    func execute(group: String, url: String, timeout: Int) async throws -> GroupDelayMeasurement {
        try await self.repository.measureGroupLatency(group: group, url: url, timeout: timeout)
    }
}
