import Foundation

protocol MaintenanceRepository: Sendable {
    func upgradeCore() async throws -> CoreUpgradeResponse
    func flushFakeIPCache() async throws
    func flushDNSCache() async throws
    func fetchVersion() async throws -> VersionInfo
}
