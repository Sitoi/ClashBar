import Foundation

@MainActor
protocol ConfigRepository: AnyObject {
    var configDirectory: URL? { get }
    var availableConfigs: [URL] { get }
    var selectedConfig: URL? { get }

    func chooseConfigDirectory() -> URL?
    func setConfigDirectory(_ url: URL)
    func selectConfig(_ url: URL)
    @discardableResult
    func reloadConfigs() -> [URL]

    func writeConfigData(_ data: Data, to targetURL: URL) throws
    func normalizedConfigFileName(_ fileName: String, fallback: String?) -> String?
    func inferredRemoteConfigFileName(from remoteURL: URL) -> String
    func isSupportedRemoteConfigURL(_ url: URL) -> Bool
    func downloadRemoteConfigData(from remoteURL: URL, userAgent: String?) async throws -> Data
}
