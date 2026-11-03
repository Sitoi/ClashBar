import CryptoKit
import Foundation

// MARK: - 快照

/// 参与同步的单个配置文件。
struct LocalConfigFile: Equatable, Sendable {
    var name: String
    var data: Data
}

/// 参与同步的本地内容。
///
/// 注意 `configs` 只包含「用户手写/自建」的配置：订阅派生的配置由各平台自行拉取，
/// 纳入同步只会让设备之间互相覆盖过期节点。过滤在 `AppViewModel+Sync` 里完成。
struct LocalSyncSnapshot: Equatable, Sendable {
    /// 配置清单，需按文件名排序以保证哈希比较稳定
    var configs: [LocalConfigFile]
    /// 跨平台设置
    var payload: SyncPayload

    /// 实际写入 `settings.json` 的字节。
    var settingsData: Data {
        get throws {
            var payload = self.payload
            payload.selectedConfig = payload.selectedConfig.trimmed
            return try JSONEncoder.sync.encode(payload)
        }
    }

    /// 配置清单（含哈希与大小），用于写入 `meta.json` 并做无变化比较
    var configEntries: [SyncedConfigEntry] {
        self.configs
            .sorted { $0.name < $1.name }
            .map {
                SyncedConfigEntry(
                    name: $0.name,
                    sha256: SyncService.sha256($0.data),
                    bytes: $0.data.count)
            }
    }
}

// MARK: - 结果

enum SyncAction: String, Sendable {
    case pushed
    case pulled
    case upToDate
}

struct SyncOutcome: Equatable, Sendable {
    var action: SyncAction
    /// 远端记录的最后修改设备
    var remoteDeviceName: String?
    var remoteUpdatedAt: Date?
    var bytesTransferred: Int
}

/// 双向同步的结果。
///
/// 拉取分支会顺带带回已下载的 `SyncPayload`，调用方无需再 `pull()` 一次（避免重复下载）。
struct SyncResult: Sendable {
    var outcome: SyncOutcome
    /// 仅当本次动作是拉取时非空
    var pulledPayload: SyncPayload?
}

// MARK: - 错误

enum SyncError: LocalizedError {
    case notConfigured
    case configFileMissing(String)
    case invalidConfigFileName(String)
    case invalidRemotePayload(String)
    case corruptedMetadata

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "尚未配置 WebDAV 同步"
        case let .configFileMissing(name):
            return "本地配置文件不存在：\(name)"
        case let .invalidConfigFileName(name):
            return "配置文件名不合法：\(name)"
        case let .invalidRemotePayload(reason):
            return "远端数据无法解析：\(reason)"
        case .corruptedMetadata:
            return "远端元信息损坏"
        }
    }
}

// MARK: - 服务

/// 负责与 WebDAV 之间的编排：打包、推送、拉取、冲突判定。
///
/// 只处理"文件 + JSON"层面，不依赖 `AppViewModel`。
/// 设置项的收集与应用由调用方（`AppViewModel+Sync`）负责。
struct SyncService: Sendable {
    /// 远端文件布局（与 `docs/sync-protocol.md` 一致）
    enum RemotePath {
        /// 同步包：`config/<name>.yaml` × N + `settings.json`
        static let bundle = "bundle.zip"
        /// 探测与校验用的元信息，体积很小（~500B）
        static let metadata = "meta.json"

        /// 旧布局（≤0.3.6）：扁平文件，仅用于迁移读取与清理
        static let legacyConfigDirectory = "config"
        static let legacySettings = "settings.json"

        static func legacyConfigFile(_ name: String) -> String {
            "\(self.legacyConfigDirectory)/\(name)"
        }
    }

    /// 旧布局使用的默认配置名
    static let defaultConfigFileName = "ClashBar.yaml"

    /// 校验并归一化配置文件名。
    ///
    /// 名称会进入远端路径、zip 条目名与本地写盘路径，必须拒绝路径分隔符与 `..`，
    /// 否则一份异常的 `settings.json` 或同步包就能把文件写到配置目录之外。
    static func normalizeConfigFileName(_ fileName: String) throws -> String {
        let name = fileName.trimmed
        let isReference = name == "."
            || name == ".."
            || name.contains("/")
            || name.contains("\\")
            || name.contains("\0")
        guard !name.isEmpty, !isReference else {
            throw SyncError.invalidConfigFileName(fileName)
        }
        return name
    }

    /// 时间容差：小于此差值视为已同步
    static let syncTolerance: TimeInterval = 30

    let client: WebDAVClient
    let directories: WorkingDirectoryManager
    let deviceName: String

    init(
        config: WebDAVConfig,
        directories: WorkingDirectoryManager = WorkingDirectoryManager(),
        deviceName: String = SyncService.defaultDeviceName) throws
    {
        self.client = try WebDAVClient(config: config)
        self.directories = directories
        self.deviceName = deviceName
    }

    // MARK: 远端查询

    func fetchRemoteMetadata() async throws -> SyncMetadata? {
        do {
            let data = try await self.client.download(RemotePath.metadata)
            guard let metadata = try? JSONDecoder.sync.decode(SyncMetadata.self, from: data) else {
                throw SyncError.corruptedMetadata
            }
            return metadata
        } catch WebDAVError.notFound {
            return nil
        }
    }

    // MARK: 推送

    @discardableResult
    func push(_ snapshot: LocalSyncSnapshot) async throws -> SyncOutcome {
        let previous = try? await self.fetchRemoteMetadata()
        return try await self.push(snapshot, previous: previous ?? nil)
    }

    /// - Parameter previous: 调用方已经取到的远端元信息；传 `nil` 表示远端为空。
    @discardableResult
    func push(_ snapshot: LocalSyncSnapshot, previous: SyncMetadata?) async throws -> SyncOutcome {
        let settingsData = try snapshot.settingsData
        let bundle = try await SyncArchive.makeBundle(
            settingsData: settingsData,
            configs: snapshot.configs)

        let metadata = SyncMetadata(
            deviceName: self.deviceName,
            updatedAt: snapshot.payload.updatedAt,
            appVersion: Self.appVersion,
            platform: "macOS",
            bundleSha256: Self.sha256(bundle),
            bundleBytes: bundle.count,
            configs: snapshot.configEntries,
            settingsSha256: Self.sha256(settingsData))

        try await self.client.ensureDirectory()

        // 顺序有意义：bundle 先写、meta 后写。
        // 万一中途失败，远端 meta 仍指向旧的 bundle（旧 bundle 已被覆盖 → 哈希不匹配），
        // 下次同步会重传而不是把半套状态当成有效快照。
        try await self.client.upload(bundle, to: RemotePath.bundle)
        try await self.client.upload(
            try JSONEncoder.sync.encode(metadata),
            to: RemotePath.metadata)

        // 从旧布局迁移过来时清理扁平文件，只做一次
        if previous?.isLegacyLayout == true {
            await self.removeLegacyLayout(snapshot: snapshot)
        }

        return SyncOutcome(
            action: .pushed,
            remoteDeviceName: metadata.deviceName,
            remoteUpdatedAt: metadata.updatedAt,
            bytesTransferred: bundle.count)
    }

    // MARK: 拉取

    /// 下载远端快照并写入本地配置目录，返回可用于应用设置的 payload。
    ///
    /// 写入前会把现有配置备份为 `*.bak-sync-<timestamp>`，失败可手动回滚。
    /// **不会删除**本地存在、但远端没有的配置：可能是本机新建还没推送的，
    /// 也可能是别的设备删掉的，自动删除风险大于收益。
    func pull() async throws -> (payload: SyncPayload, metadata: SyncMetadata) {
        guard let metadata = try await self.fetchRemoteMetadata() else {
            throw SyncError.invalidRemotePayload("远端尚未上传过配置")
        }

        guard !metadata.isLegacyLayout else {
            return try await self.pullLegacy(metadata)
        }

        let bundleData: Data
        do {
            bundleData = try await self.client.download(RemotePath.bundle)
        } catch WebDAVError.notFound {
            throw SyncError.invalidRemotePayload("远端缺少 bundle.zip")
        }

        guard Self.sha256(bundleData) == metadata.bundleSha256 else {
            throw SyncError.invalidRemotePayload("bundle.zip 与元信息哈希不匹配")
        }

        let contents = try await SyncArchive.extractBundle(
            bundleData,
            expected: metadata.configs)

        guard Self.sha256(contents.settings) == metadata.settingsSha256 else {
            throw SyncError.invalidRemotePayload("settings.json 与元信息哈希不匹配")
        }
        guard let payload = try? JSONDecoder.sync.decode(SyncPayload.self, from: contents.settings) else {
            throw SyncError.invalidRemotePayload("settings.json 格式不合法")
        }

        try self.writeLocalConfigs(contents.configs)
        return (payload, metadata)
    }

    /// 旧布局（≤0.3.6）的拉取路径：配置是 `config/<name>.yaml` 单个扁平文件。
    private func pullLegacy(_ metadata: SyncMetadata) async throws -> (payload: SyncPayload, metadata: SyncMetadata) {
        let settingsData: Data
        do {
            settingsData = try await self.client.download(RemotePath.legacySettings)
        } catch WebDAVError.notFound {
            throw SyncError.invalidRemotePayload("远端缺少 settings.json")
        }

        guard let payload = try? JSONDecoder.sync.decode(SyncPayload.self, from: settingsData) else {
            throw SyncError.invalidRemotePayload("settings.json 格式不合法")
        }

        let config = try await self.downloadLegacyConfig(for: payload.selectedConfig)

        if !metadata.legacyConfigSha256.isEmpty,
           metadata.legacyConfigSha256 != Self.sha256(config.data)
        {
            throw SyncError.invalidRemotePayload("配置内容与元信息哈希不匹配")
        }

        try self.writeLocalConfigs([LocalConfigFile(name: config.fileName, data: config.data)])
        return (payload, metadata)
    }

    /// 按 `settings.json.selectedConfig` 下载旧布局的配置，兼容固定文件名那一版。
    private func downloadLegacyConfig(for selectedConfig: String) async throws -> (data: Data, fileName: String) {
        // selectedConfig 损坏时不阻断同步，退回默认名继续尝试
        let fileName = (try? Self.normalizeConfigFileName(selectedConfig))
            ?? Self.defaultConfigFileName

        do {
            let data = try await self.client.download(RemotePath.legacyConfigFile(fileName))
            return (data, fileName)
        } catch WebDAVError.notFound {
            // 继续回退到 0.3.6 之前的固定路径
        }

        do {
            let data = try await self.client.download(RemotePath.legacyConfigFile(Self.defaultConfigFileName))
            return (data, fileName)
        } catch WebDAVError.notFound {
            throw SyncError.invalidRemotePayload("远端缺少配置文件 \(fileName)")
        }
    }

    // MARK: 双向同步

    /// 依据内容哈希与时间戳决定推送或拉取。
    func sync(_ snapshot: LocalSyncSnapshot, now: Date = Date()) async throws -> SyncResult {
        guard let remote = try await self.fetchRemoteMetadata() else {
            return SyncResult(outcome: try await self.push(snapshot, previous: nil), pulledPayload: nil)
        }

        // 内容完全一致 -> 无需传输。旧布局没有清单，直接走时间戳判定。
        if !remote.isLegacyLayout,
           Self.sha256(try snapshot.settingsData) == remote.settingsSha256,
           snapshot.configEntries == remote.configs
        {
            return SyncResult(
                outcome: SyncOutcome(
                    action: .upToDate,
                    remoteDeviceName: remote.deviceName,
                    remoteUpdatedAt: remote.updatedAt,
                    bytesTransferred: 0),
                pulledPayload: nil)
        }

        let delta = snapshot.payload.updatedAt.timeIntervalSince(remote.updatedAt)
        if delta > Self.syncTolerance {
            return SyncResult(
                outcome: try await self.push(snapshot, previous: remote),
                pulledPayload: nil)
        }

        // 远端更新（含容差内以远端为准的分支）：只拉取一次，payload 直接回传给调用方
        let pulled = try await self.pull()
        return SyncResult(
            outcome: SyncOutcome(
                action: .pulled,
                remoteDeviceName: remote.deviceName,
                remoteUpdatedAt: remote.updatedAt,
                bytesTransferred: 0),
            pulledPayload: pulled.payload)
    }

    // MARK: 旧布局清理

    /// 删除旧布局的扁平文件，避免云端同时存在 bundle 与散装配置。
    ///
    /// 全部 best-effort：失败只是留下无人读取的残留文件，不影响同步正确性。
    private func removeLegacyLayout(snapshot: LocalSyncSnapshot) async {
        var names: Set<String> = [Self.defaultConfigFileName]

        // 旧布局的配置文件名记录在旧的根 settings.json 里
        if let data = try? await self.client.download(RemotePath.legacySettings),
           let payload = try? JSONDecoder.sync.decode(SyncPayload.self, from: data),
           let name = try? Self.normalizeConfigFileName(payload.selectedConfig)
        {
            names.insert(name)
        }

        for name in names {
            try? await self.client.delete(RemotePath.legacyConfigFile(name))
        }
        try? await self.client.delete(RemotePath.legacySettings)
        // 目录可能已经空了，顺手删掉；服务器不支持时忽略
        try? await self.client.delete(RemotePath.legacyConfigDirectory)
    }

    // MARK: 本地写入

    private func writeLocalConfigs(_ configs: [LocalConfigFile]) throws {
        for config in configs {
            try self.writeLocalConfig(config.data, fileName: config.name)
        }
    }

    /// 写入配置并保留备份。
    private func writeLocalConfig(_ data: Data, fileName: String) throws {
        let directory = self.directories.configDirectoryURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 名字可能来自远端同步包，写入前必须再校验一次，防止路径穿越
        let candidate = fileName.trimmed.isEmpty ? Self.defaultConfigFileName : fileName
        let safeName = try Self.normalizeConfigFileName(candidate)
        let target = directory.appendingPathComponent(safeName, isDirectory: false)

        if FileManager.default.fileExists(atPath: target.path) {
            let stamp = Self.timestampFormatter.string(from: Date())
            let backup = directory.appendingPathComponent(
                "\(safeName).bak-sync-\(stamp)",
                isDirectory: false)
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: target, to: backup)
        }

        try data.write(to: target, options: .atomic)
    }

    // MARK: 工具

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static var defaultDeviceName: String {
        let name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        return name.trimmed.isEmpty ? "macOS" : name
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
