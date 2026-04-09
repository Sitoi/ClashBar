import Foundation

@MainActor
protocol CoreRepository: AnyObject {
    var status: CoreLifecycleStatus { get }
    var isRunning: Bool { get }
    var detectedBinaryPath: String? { get }

    func validateConfig(configPath: String) async throws
    @discardableResult
    func start(configPath: String, controller: String) async throws -> CoreLifecycleStatus
    func stop() async
    func stopImmediately()
    @discardableResult
    func restart(configPath: String, controller: String) async throws -> CoreLifecycleStatus
}
