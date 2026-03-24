import Foundation

enum SystemProxyHelperDiagnosis: Equatable {
    case healthy
    case failed(message: String)
}

@MainActor
protocol SystemProxyRepository: AnyObject {
    func apply(enabled: Bool, host: String, ports: SystemProxyPorts) async throws
    func isEnabled() async throws -> Bool
    func readActiveDisplay() async throws -> String?
    func isConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool
    func diagnoseCurrentHelper() async -> SystemProxyHelperDiagnosis
    func diagnoseAndRepair() async -> SystemProxyHelperDiagnosis
    func installHelper() async -> SystemProxyHelperDiagnosis
    func reinstallHelper() async -> SystemProxyHelperDiagnosis
    func warmUpHelperIfPossible() async
    func clearBlocking(timeout: TimeInterval)
}
