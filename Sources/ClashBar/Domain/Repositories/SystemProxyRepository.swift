import Foundation

enum SystemProxyHelperRegistrationState: Equatable, Sendable {
    case enabled
    case requiresApproval
    case notRegistered
    case unavailable
}

enum SystemProxyHelperFailureReason: String, Equatable, Sendable {
    case backgroundActivityDisabled
    case helperNotRegistered
    case helperStartTimedOut
    case helperConnectionFailed
    case helperOperationFailed
    case appNotInApplications
    case helperNotBundled
    case signatureMismatch
    case unknown
}

struct SystemProxyHelperHealthSnapshot: Equatable, Sendable {
    let registrationState: SystemProxyHelperRegistrationState
    let backgroundActivityAllowed: Bool
    let processRunning: Bool
    let failureReason: SystemProxyHelperFailureReason?
    let rawMessage: String?
}

@MainActor
protocol SystemProxyRepository: AnyObject {
    func apply(enabled: Bool, host: String, ports: SystemProxyPorts) async throws
    func isEnabled() async throws -> Bool
    func readActiveDisplay() async throws -> String?
    func readExceptionsList() async throws -> [String]
    func setExceptionsList(_ exceptions: [String]) async throws
    func readHelperHealthSnapshot() async -> SystemProxyHelperHealthSnapshot
    func isConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool
    func warmUpHelperIfPossible() async
    func clearBlocking(timeout: TimeInterval)
}
