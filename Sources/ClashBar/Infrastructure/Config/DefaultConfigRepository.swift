import Foundation

@MainActor
final class DefaultConfigRepository: ConfigRepository {
    private let configManager: ConfigDirectoryManager
    private let configImportService: ConfigImportService

    init(
        configManager: ConfigDirectoryManager,
        configImportService: ConfigImportService)
    {
        self.configManager = configManager
        self.configImportService = configImportService
    }

    var configDirectory: URL? {
        self.configManager.configDirectory
    }

    var availableConfigs: [URL] {
        self.configManager.availableConfigs
    }

    var selectedConfig: URL? {
        self.configManager.selectedConfig
    }

    func chooseConfigDirectory() -> URL? {
        self.configManager.chooseConfigDirectory()
    }

    func setConfigDirectory(_ url: URL) {
        self.configManager.setConfigDirectory(url)
    }

    func selectConfig(_ url: URL) {
        self.configManager.selectConfig(url)
    }

    @discardableResult
    func reloadConfigs() -> [URL] {
        self.configManager.reloadConfigs()
    }

    func writeConfigData(_ data: Data, to targetURL: URL) throws {
        try self.configImportService.writeConfigData(data, to: targetURL)
    }

    func normalizedConfigFileName(_ fileName: String, fallback: String? = nil) -> String? {
        self.configImportService.normalizedConfigFileName(fileName, fallback: fallback)
    }

    func inferredRemoteConfigFileName(from remoteURL: URL) -> String {
        self.configImportService.inferredRemoteConfigFileName(from: remoteURL)
    }

    func isSupportedRemoteConfigURL(_ url: URL) -> Bool {
        self.configImportService.isSupportedRemoteConfigURL(url)
    }

    func downloadRemoteConfigData(from remoteURL: URL, userAgent: String? = nil) async throws -> Data {
        try await self.configImportService.downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
    }
}
