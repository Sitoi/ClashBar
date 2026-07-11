import Foundation

struct WorkingDirectoryManager {
    let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    var rootDirectoryURL: URL {
        self.homeDirectory.appendingPathComponent("Library/Application Support/clashbar", isDirectory: true)
    }

    var configDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("config", isDirectory: true)
    }

    var logsDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("logs", isDirectory: true)
    }

    var stateDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("state", isDirectory: true)
    }

    var iconDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("icon", isDirectory: true)
    }

    var coreDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("core", isDirectory: true)
    }

    var managedMihomoBinaryURL: URL {
        self.coreDirectoryURL.appendingPathComponent("mihomo", isDirectory: false)
    }

    func bootstrapDirectories(fileManager: FileManager = .default) throws {
        try self.createDirectoryIfNeeded(self.rootDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.configDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.logsDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.stateDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.iconDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.coreDirectoryURL, fileManager: fileManager)
    }

    func normalizeAndValidateWithinRoot(_ url: URL, mustBeDirectory: Bool? = nil) throws -> URL {
        let standardized = url.standardizedFileURL
        let root = self.rootDirectoryURL.standardizedFileURL
        guard self.isDescendantOrEqual(standardized, parent: root) else {
            throw NSError(
                domain: "ClashBar.PathSecurity",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path escapes ClashBar working directory: \(standardized.path)"])
        }

        if let mustBeDirectory {
            let resolved = standardized.resolvingSymlinksInPath()
            let values = try resolved.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory != mustBeDirectory {
                throw NSError(
                    domain: "ClashBar.PathSecurity",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: mustBeDirectory
                        ? "Expected directory path: \(standardized.path)"
                        : "Expected file path: \(standardized.path)"])
            }
        }

        return standardized
    }

    private func createDirectoryIfNeeded(_ url: URL, fileManager: FileManager) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw NSError(
                    domain: "ClashBar.PathSecurity",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Expected directory but found file: \(url.path)"])
            }
            return
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func isDescendantOrEqual(_ child: URL, parent: URL) -> Bool {
        let childComponents = child.pathComponents
        let parentComponents = parent.pathComponents

        guard parentComponents.count <= childComponents.count else { return false }
        return zip(parentComponents, childComponents).allSatisfy { $0 == $1 }
    }
}

@MainActor
final class ConfigDirectoryManager {
    private let workingDirectoryManager: WorkingDirectoryManager

    private(set) var configDirectory: URL?
    private(set) var availableConfigs: [URL] = []
    private(set) var selectedConfig: URL?

    init(workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager()) {
        self.workingDirectoryManager = workingDirectoryManager
    }

    func chooseConfigDirectory() -> URL? {
        do {
            try self.workingDirectoryManager.bootstrapDirectories()
            let target = try workingDirectoryManager.normalizeAndValidateWithinRoot(
                self.workingDirectoryManager.configDirectoryURL,
                mustBeDirectory: true)
            self.configDirectory = target
            self.reloadConfigs()
            return target
        } catch {
            return nil
        }
    }

    func setConfigDirectory(_ url: URL) {
        guard let safeURL = try? workingDirectoryManager.normalizeAndValidateWithinRoot(url, mustBeDirectory: true),
              safeURL == workingDirectoryManager.configDirectoryURL.standardizedFileURL
        else {
            return
        }
        self.configDirectory = safeURL
        self.reloadConfigs()
    }

    func selectConfig(_ url: URL) {
        guard let configDirectory else { return }
        let safeConfig = try? self.workingDirectoryManager.normalizeAndValidateWithinRoot(url, mustBeDirectory: false)
        guard let safeConfig,
              safeConfig.deletingLastPathComponent() == configDirectory,
              ["yaml", "yml"].contains(safeConfig.pathExtension.lowercased())
        else {
            return
        }
        self.selectedConfig = safeConfig
    }

    @discardableResult
    func reloadConfigs() -> [URL] {
        guard let configDirectory else {
            self.applyScannedConfigs([])
            return []
        }

        let files = Self.scanConfigFiles(in: configDirectory)
        self.applyScannedConfigs(files)
        return files
    }

    func applyScannedConfigs(_ files: [URL]) {
        self.availableConfigs = files
        if let selectedConfig, files.contains(selectedConfig) {
            return
        }
        self.selectedConfig = files.first
    }

    nonisolated static func scanConfigFiles(in directory: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles])) ?? []

        return children.filter { fileURL in
            let resolved = fileURL.resolvingSymlinksInPath()
            let isRegularFile = (try? resolved.resourceValues(forKeys: keys).isRegularFile) ?? false
            let fileExtension = fileURL.pathExtension.lowercased()
            return isRegularFile && (fileExtension == "yaml" || fileExtension == "yml")
        }.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }
}

struct ConfigImportService {
    private let maxRemoteConfigBytes = 5 * 1024 * 1024

    func writeConfigData(_ data: Data, to targetURL: URL) throws {
        guard !data.isEmpty else {
            throw NSError(
                domain: "ClashBar.ConfigImport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Remote config response is empty"])
        }

        guard self.validateClashConfigData(data) else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary data>"
            let message = """
            Remote config is not a valid Clash configuration (missing proxy keys). \
            Content preview: \(preview)
            """
            throw NSError(
                domain: "ClashBar.ConfigImport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: message])
        }

        try data.write(to: targetURL, options: .atomic)
    }

    private func validateClashConfigData(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else {
            return false
        }

        let hasProxies = text.contains("proxies:")
        let hasProxyGroups = text.contains("proxy-groups:")
        let hasProxyProviders = text.contains("proxy-providers:")

        return hasProxies || hasProxyGroups || hasProxyProviders
    }

    func normalizedConfigFileName(_ fileName: String, fallback: String? = nil) -> String? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? (fallback ?? "") : trimmed
        let candidate = URL(fileURLWithPath: baseName).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate != ".", candidate != ".." else { return nil }

        let ext = (candidate as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            return "\(candidate).yaml"
        }
        guard ext == "yaml" || ext == "yml" else { return nil }
        return candidate
    }

    func inferredRemoteConfigFileName(from remoteURL: URL) -> String {
        let rawName = remoteURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return "remote-config.yaml" }

        let ext = (rawName as NSString).pathExtension.lowercased()
        if ext == "yaml" || ext == "yml" {
            return rawName
        }

        if ext.isEmpty {
            return "\(rawName).yaml"
        }

        let stem = (rawName as NSString).deletingPathExtension
        let base = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "remote-config.yaml" : "\(base).yaml"
    }

    func isSupportedRemoteConfigURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    func downloadRemoteConfigData(from remoteURL: URL, userAgent: String? = nil) async throws -> Data {
        let session = URLSessionFactory.makeEphemeralSession(options: .init(
            timeoutIntervalForRequest: 15,
            timeoutIntervalForResource: 30))
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: remoteURL)
        if let userAgent {
            let trimmed = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                request.setValue(trimmed, forHTTPHeaderField: "User-Agent")
            }
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIError.statusCode(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }

        if http.expectedContentLength > Int64(self.maxRemoteConfigBytes) {
            throw self.remoteConfigTooLargeError(limit: self.maxRemoteConfigBytes)
        }

        var data = Data()
        data.reserveCapacity(min(self.maxRemoteConfigBytes, 64 * 1024))
        for try await byte in bytes {
            if data.count >= self.maxRemoteConfigBytes {
                throw self.remoteConfigTooLargeError(limit: self.maxRemoteConfigBytes)
            }
            data.append(byte)
        }
        return data
    }

    private func remoteConfigTooLargeError(limit: Int) -> NSError {
        NSError(
            domain: "ClashBar.ConfigImport",
            code: 413,
            userInfo: [NSLocalizedDescriptionKey: "Remote config exceeds size limit (\(limit) bytes)"])
    }
}

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

    func applyScannedConfigs(_ files: [URL]) {
        self.configManager.applyScannedConfigs(files)
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
