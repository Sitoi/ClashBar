import Foundation

struct AppLogRotationPolicy {
    let maxFileSizeBytes: UInt64
    let maxBackupCount: Int

    static let `default` = AppLogRotationPolicy(
        maxFileSizeBytes: 10 * 1024 * 1024,
        maxBackupCount: 5)
}

final class AppLogStore: @unchecked Sendable {
    let logFileURL: URL
    let rotationPolicy: AppLogRotationPolicy

    private let ioQueue: DispatchQueue
    private let timestampFormatter: DateFormatter

    init(logFileURL: URL, rotationPolicy: AppLogRotationPolicy = .default) {
        self.logFileURL = logFileURL
        self.rotationPolicy = rotationPolicy
        self.ioQueue = DispatchQueue(
            label: "com.clashbar.log.\(logFileURL.lastPathComponent)",
            qos: .utility)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.timestampFormatter = formatter
    }

    func ensureLogFileExists() {
        self.ioQueue.async { [self] in
            self.ensureLogFileExistsOnQueue()
        }
    }

    func append(entries: [AppErrorLogEntry]) {
        guard !entries.isEmpty else { return }
        let records = entries.map {
            (timestamp: $0.timestamp, level: $0.level, message: $0.message)
        }

        self.ioQueue.async { [self] in
            self.appendOnQueue(records: records)
        }
    }

    func clear() {
        self.ioQueue.async { [self] in
            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                try? Data().write(to: self.logFileURL, options: .atomic)
            } else {
                self.ensureLogFileExistsOnQueue()
            }
        }
    }

    /// Waits for all previously submitted log operations to finish.
    func flush() {
        self.ioQueue.sync {}
    }

    private func appendOnQueue(records: [(timestamp: Date, level: String, message: String)]) {
        let content = records.map {
            "[\(self.timestampFormatter.string(from: $0.timestamp))] [\($0.level.uppercased())] \($0.message)\n"
        }.joined()
        guard let data = content.data(using: .utf8) else { return }

        self.ensureLogFileExistsOnQueue()
        self.rotateIfNeeded(incomingDataSize: UInt64(data.count))
        guard let handle = FileHandle(forWritingAtPath: self.logFileURL.path) else { return }
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(data)
    }

    private func ensureLogFileExistsOnQueue() {
        if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
            FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
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

        self.ensureLogFileExistsOnQueue()
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
}
