import Foundation

enum AdministratorShell {
    static func run(_ shellCommand: String, cancelled: Error, failed: (String) -> Error) throws {
        let script = "do shell script \"\(self.appleScriptEscaped(shellCommand))\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw failed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = [stderr, stdout]
                .first(where: { !$0.isEmpty }) ?? "Unknown authorization error."
            if message.lowercased().contains("user canceled") || message.contains("-128") {
                throw cancelled
            }
            throw failed(message)
        }
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
