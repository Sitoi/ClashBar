import Foundation

@MainActor
protocol SystemProxyRepository: AnyObject {
    func apply(enabled: Bool, host: String, ports: SystemProxyPorts) async throws
    func isEnabled() async throws -> Bool
    func isConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool
    func warmUpHelperIfPossible() async
    func clearBlocking(timeout: TimeInterval)
}
