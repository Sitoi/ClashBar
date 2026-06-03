import Foundation

struct AppLogRotationPolicy {
    let maxFileSizeBytes: UInt64
    let maxBackupCount: Int

    static let `default` = AppLogRotationPolicy(
        maxFileSizeBytes: 10 * 1024 * 1024,
        maxBackupCount: 5)
}

struct AppLogStore {
    let logFileURL: URL
    let rotationPolicy: AppLogRotationPolicy
    /// Reference type: struct copies share the same lock, guaranteeing mutual
    /// exclusion even if the store is passed across actor boundaries or captured
    /// by background tasks. Each distinct `init(logFileURL:)` gets a fresh lock.
    private let ioLock = NSLock()

    init(logFileURL: URL, rotationPolicy: AppLogRotationPolicy = .default) {
        self.logFileURL = logFileURL
        self.rotationPolicy = rotationPolicy
    }

    func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
            FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
        }
    }

    func append(entries: [AppErrorLogEntry]) {
        self.append(records: entries.map {
            (timestamp: $0.timestamp, level: $0.level, message: $0.message)
        })
    }

    private func append(records: [(timestamp: Date, level: String, message: String)]) {
        guard !records.isEmpty else { return }
        let content = records.map {
            "[\(Self.timestampString(from: $0.timestamp))] [\($0.level.uppercased())] \($0.message)\n"
        }.joined()
        guard let data = content.data(using: .utf8) else { return }

        self.ioLock.withLock {
            self.ensureLogFileExists()
            self.rotateIfNeeded(incomingDataSize: UInt64(data.count))
            guard let handle = FileHandle(forWritingAtPath: logFileURL.path) else { return }
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    func clear() {
        self.ioLock.withLock {
            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                try? Data().write(to: self.logFileURL, options: .atomic)
            } else {
                self.ensureLogFileExists()
            }
        }
    }

    private func rotateIfNeeded(incomingDataSize: UInt64) {
        guard self.rotationPolicy.maxFileSizeBytes > 0,
              self.rotationPolicy.maxBackupCount > 0
        else { return }

        let currentFileSize = self.fileSize(at: self.logFileURL)
        guard currentFileSize + incomingDataSize > self.rotationPolicy.maxFileSizeBytes else { return }

        let fileManager = FileManager.default
        let oldestBackupURL = self.rotatedLogFileURL(index: self.rotationPolicy.maxBackupCount)
        if fileManager.fileExists(atPath: oldestBackupURL.path) {
            try? fileManager.removeItem(at: oldestBackupURL)
        }

        if self.rotationPolicy.maxBackupCount > 1 {
            for index in stride(from: self.rotationPolicy.maxBackupCount - 1, through: 1, by: -1) {
                let sourceURL = self.rotatedLogFileURL(index: index)
                guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

                let destinationURL = self.rotatedLogFileURL(index: index + 1)
                try? fileManager.moveItem(at: sourceURL, to: destinationURL)
            }
        }

        if fileManager.fileExists(atPath: self.logFileURL.path), currentFileSize > 0 {
            try? fileManager.moveItem(at: self.logFileURL, to: self.rotatedLogFileURL(index: 1))
        }

        self.ensureLogFileExists()
    }

    private func rotatedLogFileURL(index: Int) -> URL {
        URL(fileURLWithPath: "\(self.logFileURL.path).\(index)")
    }

    private func fileSize(at url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes?[.size] as? NSNumber {
            return size.uint64Value
        }
        return attributes?[.size] as? UInt64 ?? 0
    }

    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt
    }()

    private static func timestampString(from date: Date) -> String {
        self.timestampFormatter.string(from: date)
    }
}
