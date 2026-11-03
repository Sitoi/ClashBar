import Foundation

/// 同步包（`bundle.zip`）的构建与安全解包。
///
/// 为什么用系统 `ditto` 而不是引第三方 zip 依赖：
/// - Foundation / `AppleArchive` 都不支持 zip 容器，`Compression` 只有裸算法
/// - 只为同步一个 <50KB 的包进依赖树不划算
///
/// 为什么自己解析中央目录而不是用 `unzip -Z1`：
/// - Apple 自带的 Info-ZIP 不认 zip 的 UTF-8 名字标志，中文文件名会变乱码
/// - 还需要 unix mode 才能识别符号链接条目
enum SyncArchive {
    /// bundle 内的配置目录名
    static let configDirectory = "config"
    /// bundle 内的设置文件名，位于包根
    static let settingsFileName = "settings.json"

    /// 允许的最大条目数
    static let maxEntryCount = 512
    /// 解压后允许的总字节上限（防 zip bomb）
    static let maxUncompressedBytes = 32 * 1024 * 1024
    /// 单条外部命令的超时
    static let commandTimeout: TimeInterval = 60

    enum ArchiveError: LocalizedError {
        case toolMissing(String)
        case commandFailed(tool: String, status: Int32, detail: String)
        case commandTimedOut(String)
        case notAZip
        case undecodableEntryName
        case zip64Unsupported
        case tooManyEntries(Int)
        case tooLarge(Int)
        case unexpectedEntry(String)
        case missingEntry(String)
        case bundleMismatch(expected: [String], actual: [String])
        case notARegularFile(String)
        case sizeMismatch(name: String, expected: Int, actual: Int)
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case let .toolMissing(tool):
                return "缺少系统工具：\(tool)"
            case let .commandFailed(tool, status, detail):
                return "\(tool) 执行失败（退出码 \(status)）：\(detail)"
            case let .commandTimedOut(tool):
                return "\(tool) 执行超时"
            case .notAZip:
                return "同步包不是合法的 zip"
            case .undecodableEntryName:
                return "同步包内存在无法识别的文件名"
            case .zip64Unsupported:
                return "同步包含 ZIP64 或超大条目，不支持"
            case let .tooManyEntries(count):
                return "同步包条目过多（\(count)）"
            case let .tooLarge(bytes):
                return "同步包解压后体积超限（\(bytes) 字节）"
            case let .unexpectedEntry(name):
                return "同步包含有未声明的条目：\(name)"
            case let .missingEntry(name):
                return "同步包缺少条目：\(name)"
            case let .bundleMismatch(expected, actual):
                let lhs = expected.joined(separator: ", ")
                let rhs = actual.joined(separator: ", ")
                return "同步包内容与元信息不一致（元信息：\(lhs)；实际：\(rhs)）"
            case let .notARegularFile(name):
                return "同步包条目不是普通文件：\(name)"
            case let .sizeMismatch(name, expected, actual):
                return "\(name) 大小不符（期望 \(expected)，实际 \(actual)）"
            case let .checksumMismatch(name):
                return "\(name) 校验和不匹配"
            }
        }
    }

    /// 解包结果
    struct Contents {
        var settings: Data
        var configs: [LocalConfigFile]
    }

    // MARK: - 打包

    /// 把 `settings.json` 与若干配置文件打成一个 zip 包，返回包内容。
    static func makeBundle(settingsData: Data, configs: [LocalConfigFile]) async throws -> Data {
        let root = try makeWorkDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let stage = root.appendingPathComponent("bundle", isDirectory: true)
        let configDirectoryURL = stage.appendingPathComponent(configDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        // 配置数量为 0（只用订阅）时不建 config/，包内就只有 settings.json
        if !configs.isEmpty {
            try FileManager.default.createDirectory(
                at: configDirectoryURL,
                withIntermediateDirectories: true)
        }

        try settingsData.write(to: stage.appendingPathComponent(settingsFileName))
        for file in configs {
            // 名字会进入远端路径与本地写盘路径，统一走同一套校验
            let name = try SyncService.normalizeConfigFileName(file.name)
            try file.data.write(to: configDirectoryURL.appendingPathComponent(name))
        }

        let zipURL = root.appendingPathComponent("bundle.zip")
        try await runCommand("/usr/bin/ditto", [
            "-c", "-k",
            "--norsrc", "--noextattr", "--noqtn",
            "--zlibCompressionLevel", "9",
            stage.path,
            zipURL.path,
        ])
        return try Data(contentsOf: zipURL)
    }

    // MARK: - 解包

    /// 解包并校验。
    ///
    /// 顺序是硬性的：**先校验条目名，再解压，再校验内容**。
    /// 反过来就晚了 —— `ditto -x` 会还原符号链接，先解压等于先把攻击面落到磁盘上。
    static func extractBundle(_ data: Data, expected: [SyncedConfigEntry]) async throws -> Contents {
        guard data.count <= maxUncompressedBytes else {
            throw ArchiveError.tooLarge(data.count)
        }

        let entries = try ZipInspector.entries(in: data)
        let declaredNames = try validate(entries: entries, expected: expected)

        let root = try makeWorkDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let zipURL = root.appendingPathComponent("bundle.zip")
        try data.write(to: zipURL)
        let outputDirectory = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        try await runCommand("/usr/bin/ditto", ["-x", "-k", zipURL.path, outputDirectory.path])

        let settingsURL = outputDirectory.appendingPathComponent(settingsFileName)
        let settings = try readRegularFile(settingsURL, name: settingsFileName)

        let expectedByName = Dictionary(uniqueKeysWithValues: expected.map { ($0.name, $0) })
        var configs: [LocalConfigFile] = []
        for name in declaredNames {
            let url = outputDirectory
                .appendingPathComponent(configDirectory, isDirectory: true)
                .appendingPathComponent(name)
            let contents = try readRegularFile(url, name: "\(configDirectory)/\(name)")
            guard let entry = expectedByName[name] else {
                throw ArchiveError.unexpectedEntry("\(configDirectory)/\(name)")
            }
            guard contents.count == entry.bytes else {
                throw ArchiveError.sizeMismatch(
                    name: entry.name,
                    expected: entry.bytes,
                    actual: contents.count)
            }
            guard SyncService.sha256(contents) == entry.sha256 else {
                throw ArchiveError.checksumMismatch(entry.name)
            }
            configs.append(LocalConfigFile(name: name, data: contents))
        }

        return Contents(settings: settings, configs: configs)
    }

    /// 校验条目白名单，返回 bundle 内声明的配置文件名（未排序）。
    private static func validate(
        entries: [ZipInspector.Entry],
        expected: [SyncedConfigEntry]) throws -> [String]
    {
        guard !entries.isEmpty else { throw ArchiveError.notAZip }
        guard entries.count <= maxEntryCount else {
            throw ArchiveError.tooManyEntries(entries.count)
        }

        var declaredSettings = false
        var configNames: [String] = []
        var seenNames = Set<String>()
        var totalBytes = 0

        for entry in entries {
            guard seenNames.insert(entry.name).inserted else {
                throw ArchiveError.unexpectedEntry(entry.name)
            }

            totalBytes += Int(entry.uncompressedSize)
            guard totalBytes <= maxUncompressedBytes else {
                throw ArchiveError.tooLarge(totalBytes)
            }

            if entry.name == settingsFileName {
                guard !entry.isDirectory, !entry.isSymlink else {
                    throw ArchiveError.unexpectedEntry(entry.name)
                }
                declaredSettings = true
                continue
            }

            if entry.name == "\(configDirectory)/" || entry.name == configDirectory {
                guard entry.isDirectory else {
                    throw ArchiveError.unexpectedEntry(entry.name)
                }
                continue
            }

            let prefix = "\(configDirectory)/"
            guard entry.name.hasPrefix(prefix), !entry.isDirectory else {
                throw ArchiveError.unexpectedEntry(entry.name)
            }

            // 只允许 config/<单层文件名>：含 `/`、`..`、绝对路径的一律在这里被拒
            let rawName = String(entry.name.dropFirst(prefix.count))
            let name = try SyncService.normalizeConfigFileName(rawName)
            guard !entry.isSymlink, entry.isRegularFileIfDeclared else {
                throw ArchiveError.unexpectedEntry(entry.name)
            }
            configNames.append(name)
        }

        guard declaredSettings else { throw ArchiveError.missingEntry(settingsFileName) }

        // bundle 内的配置必须与 meta 清单逐个对应，多一个少一个都不行
        let expectedNames = expected.map(\.name).sorted()
        let actualNames = configNames.sorted()
        guard expectedNames == actualNames else {
            throw ArchiveError.bundleMismatch(expected: expectedNames, actual: actualNames)
        }

        return configNames
    }

    /// 读取并确认是普通文件（不跟随符号链接）。
    private static func readRegularFile(_ url: URL, name: String) throws -> Data {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            throw ArchiveError.missingEntry(name)
        }
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw ArchiveError.notARegularFile(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - 外部命令

    private static func makeWorkDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClashBarSync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 跑一个本地工具，返回 stdout+stderr 的合并输出。
    ///
    /// 用 `Task.detached` + 轮询而不是 `waitUntilExit()`：这里不能阻塞协作线程，
    /// 同时需要超时兜底（`ditto` 卡住会让整个同步永远停在进行中）。
    @discardableResult
    private static func runCommand(_ tool: String, _ arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: tool) else {
            throw ArchiveError.toolMissing(tool)
        }

        return try await Task.detached(priority: .utility) { () -> Data in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                throw ArchiveError.commandFailed(
                    tool: tool,
                    status: -1,
                    detail: error.localizedDescription)
            }

            let deadline = Date().addingTimeInterval(commandTimeout)
            while process.isRunning, Date() < deadline {
                // 用 usleep 而不是 Thread.sleep：后者在 async 上下文中不可用
                usleep(20_000)
            }

            var timedOut = false
            if process.isRunning {
                timedOut = true
                process.terminate()
                usleep(100_000)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }

            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            if timedOut {
                throw ArchiveError.commandTimedOut(tool)
            }
            guard process.terminationStatus == 0 else {
                let detail = String(data: output, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw ArchiveError.commandFailed(
                    tool: tool,
                    status: process.terminationStatus,
                    detail: detail.isEmpty ? "无输出" : detail)
            }
            return output
        }.value
    }
}

// MARK: - zip 中央目录

/// 只读 zip 的中央目录，取出条目名与 unix mode。
///
/// 不实现解压，只做「解压前的事实查询」。ZIP64 与加密条目一律拒绝：
/// 同步包正常只有几十 KB、几个条目。
enum ZipInspector {
    struct Entry {
        var name: String
        var uncompressedSize: UInt32
        var externalAttributes: UInt32

        var isDirectory: Bool {
            self.name.hasSuffix("/")
        }

        /// 高 16 位是 unix mode；为 0 表示没写（例如某些 Windows 打包器）
        var unixMode: UInt16 {
            UInt16(truncatingIfNeeded: self.externalAttributes >> 16)
        }

        private var fileType: UInt16 {
            self.unixMode & 0o170000
        }

        var isSymlink: Bool {
            self.fileType == 0o120000
        }

        /// 没声明 unix mode 时视为「未知」，交给解压后的普通文件检查兜底
        var isRegularFileIfDeclared: Bool {
            self.fileType == 0 || self.fileType == 0o100000
        }
    }

    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectorySignature: UInt32 = 0x0201_4B50
    private static let zip64Marker: UInt32 = 0xFFFF_FFFF
    /// EOCD 最大回溯长度 = 22 + 65535（注释上限）
    private static let endOfCentralDirectorySearchLimit = 22 + 65_535

    static func entries(in data: Data) throws -> [Entry] {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw SyncArchive.ArchiveError.notAZip }

        func u16(_ index: Int) -> UInt16 {
            UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
        }

        func u32(_ index: Int) -> UInt32 {
            UInt32(bytes[index])
                | UInt32(bytes[index + 1]) << 8
                | UInt32(bytes[index + 2]) << 16
                | UInt32(bytes[index + 3]) << 24
        }

        // 从尾部往前找 EOCD 签名
        var endOfCentralDirectory = -1
        var cursor = bytes.count - 22
        let lowerBound = max(0, bytes.count - endOfCentralDirectorySearchLimit)
        while cursor >= lowerBound {
            if u32(cursor) == endOfCentralDirectorySignature {
                endOfCentralDirectory = cursor
                break
            }
            cursor -= 1
        }
        guard endOfCentralDirectory >= 0 else { throw SyncArchive.ArchiveError.notAZip }

        let totalEntries = Int(u16(endOfCentralDirectory + 10))
        let centralDirectorySize = Int(u32(endOfCentralDirectory + 12))
        let centralDirectoryOffset = Int(u32(endOfCentralDirectory + 16))

        guard totalEntries > 0, totalEntries <= SyncArchive.maxEntryCount else {
            throw SyncArchive.ArchiveError.tooManyEntries(totalEntries)
        }
        guard centralDirectoryOffset >= 0,
              centralDirectorySize >= 0,
              centralDirectoryOffset + centralDirectorySize <= bytes.count
        else {
            throw SyncArchive.ArchiveError.notAZip
        }

        var result: [Entry] = []
        result.reserveCapacity(totalEntries)
        var offset = centralDirectoryOffset

        for _ in 0 ..< totalEntries {
            guard offset + 46 <= bytes.count, u32(offset) == centralDirectorySignature else {
                throw SyncArchive.ArchiveError.notAZip
            }

            let flags = u16(offset + 8)
            let compressedSize = u32(offset + 20)
            let uncompressedSize = u32(offset + 24)
            let nameLength = Int(u16(offset + 28))
            let extraLength = Int(u16(offset + 30))
            let commentLength = Int(u16(offset + 32))
            let externalAttributes = u32(offset + 38)

            // bit 0 = 加密；ZIP64 用全 F 标记
            guard flags & 0x0001 == 0,
                  compressedSize != zip64Marker,
                  uncompressedSize != zip64Marker
            else {
                throw SyncArchive.ArchiveError.zip64Unsupported
            }

            let nameStart = offset + 46
            guard nameStart + nameLength <= bytes.count else {
                throw SyncArchive.ArchiveError.notAZip
            }
            guard let name = String(
                bytes: bytes[nameStart ..< (nameStart + nameLength)],
                encoding: .utf8)
            else {
                throw SyncArchive.ArchiveError.undecodableEntryName
            }

            result.append(Entry(
                name: name,
                uncompressedSize: uncompressedSize,
                externalAttributes: externalAttributes))

            offset = nameStart + nameLength + extraLength + commentLength
        }

        return result
    }
}
