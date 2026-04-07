import Foundation

struct MeasureProxyLatencyUseCase {
    private let repository: any ProxyRepository

    init(repository: any ProxyRepository) {
        self.repository = repository
    }

    func execute(name: String, url: String, timeout: Int) async throws -> DelayMeasurement {
        try await self.repository.measureProxyLatency(name: name, url: url, timeout: timeout)
    }
}
