import Foundation

struct DefaultMaintenanceRepository: MaintenanceRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func upgradeCore() async throws -> CoreUpgradeResponse {
        try await self.transport.request(.upgradeCore)
    }

    func flushFakeIPCache() async throws {
        try await self.transport.requestNoResponse(.flushFakeIPCache)
    }

    func flushDNSCache() async throws {
        try await self.transport.requestNoResponse(.flushDNSCache)
    }

    func fetchVersion() async throws -> VersionInfo {
        try await self.transport.request(.version)
    }
}
