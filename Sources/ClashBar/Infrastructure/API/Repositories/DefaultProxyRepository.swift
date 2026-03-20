import Foundation

struct DefaultProxyRepository: ProxyRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func switchProxy(group: String, target: String) async throws {
        try await self.transport.requestNoResponse(.switchProxy(name: group, target: target))
    }

    func measureGroupLatency(group: String, url: String, timeout: Int) async throws -> GroupDelayMeasurement {
        try await self.transport.request(.groupDelay(name: group, url: url, timeout: timeout))
    }
}
