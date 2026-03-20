import Foundation

struct DefaultRuntimeConfigRepository: RuntimeConfigRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func fetchConfig() async throws -> ConfigSnapshot {
        try await self.transport.request(.getConfigs)
    }

    func patchConfig(body: [String: JSONValue]) async throws {
        try await self.transport.requestNoResponse(.patchConfigs(body: body))
    }

    func reloadConfig(force: Bool) async throws {
        try await self.transport.requestNoResponse(.putConfigs(force: force))
    }
}
