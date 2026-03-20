import Foundation

protocol RuntimeConfigRepository: Sendable {
    func fetchConfig() async throws -> ConfigSnapshot
    func patchConfig(body: [String: JSONValue]) async throws
    func reloadConfig(force: Bool) async throws
}
