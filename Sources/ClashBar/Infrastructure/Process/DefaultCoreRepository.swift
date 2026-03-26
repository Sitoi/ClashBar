import Foundation

@MainActor
final class DefaultCoreRepository: CoreRepository {
    private let processManager: any MihomoControlling

    init(processManager: any MihomoControlling) {
        self.processManager = processManager
    }

    var status: CoreLifecycleStatus {
        self.processManager.status
    }

    var isRunning: Bool {
        self.processManager.isRunning
    }

    var detectedBinaryPath: String? {
        self.processManager.detectedBinaryPath
    }

    func validateConfig(configPath: String) async throws {
        try await self.processManager.validateConfigAsync(configPath: configPath)
    }

    @discardableResult
    func start(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.processManager.startAsync(configPath: configPath, controller: controller)
    }

    func stop() async {
        await self.processManager.stopAsync()
    }

    func stopImmediately() {
        self.processManager.stop()
    }

    @discardableResult
    func restart(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.processManager.restartAsync(configPath: configPath, controller: controller)
    }
}
