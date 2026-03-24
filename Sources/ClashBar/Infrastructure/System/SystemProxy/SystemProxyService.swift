import Foundation
import os
import ProxyHelperShared
import Security
import ServiceManagement

enum SystemProxyServiceError: LocalizedError {
    case invalidHost
    case invalidPort
    case helperNotBundled
    case helperNotInstalled
    case helperRequiresInstallToApplications
    case helperNeedsApproval
    case helperBlockedBySystemPolicy(String)
    case helperInvalidSignature(String)
    case helperRegistrationFailed(String)
    case helperConnectionFailed(String)
    case helperOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Invalid proxy host."
        case .invalidPort:
            "Invalid proxy port."
        case .helperNotBundled:
            "Privileged helper not found in app bundle. Please rebuild and run the packaged app."
        case .helperNotInstalled:
            "Privileged helper is not installed. Use Install or Reinstall helper."
        case .helperRequiresInstallToApplications:
            "Privileged helper can only be installed from /Applications. " +
                "Move ClashBar.app to /Applications and reopen it."
        case .helperNeedsApproval:
            "Privileged helper requires approval in System Settings > Login Items."
        case let .helperBlockedBySystemPolicy(message):
            "Privileged helper was blocked by system policy: \(message)"
        case let .helperInvalidSignature(message):
            "Privileged helper signature invalid: \(message)"
        case let .helperRegistrationFailed(message):
            "Failed to register privileged helper: \(message)"
        case let .helperConnectionFailed(message):
            "Failed to connect privileged helper: \(message)"
        case let .helperOperationFailed(message):
            "Privileged helper operation failed: \(message)"
        }
    }
}

private final class ContinuationBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Value, Error>) {
        self.lock.lock()
        guard let continuation else {
            self.lock.unlock()
            return
        }
        self.continuation = nil
        self.lock.unlock()

        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

struct SystemProxyService {
    private let helperToolInstallPath = "/Library/PrivilegedHelperTools/com.clashbar.helper"
    private let helperPlistInstallPath = "/Library/LaunchDaemons/com.clashbar.helper.plist"

    private let helperResponseTimeoutNanoseconds: UInt64 = 4_000_000_000

    private static let legacyInstallGate = LegacyInstallGate()

    private final class LegacyInstallGate: Sendable {
        private let state = OSAllocatedUnfairLock(initialState: false)
        func tryAcquire() -> Bool {
            self.state.withLock { inProgress in
                if inProgress { return false }
                inProgress = true
                return true
            }
        }

        func release() {
            self.state.withLock { $0 = false }
        }
    }

    private enum HelperRegistrationResult {
        case ready
        case needsApproval
        case blocked(String)
        case failed(String)
    }

    func warmUpHelperIfPossible() async {
        guard self.isHelperBundledInMainApp() else { return }
        guard !self.isRunningFromReadOnlyVolume() else { return }

        if self.isHelperInstalledInSystem() {
            _ = try? await self.invokeStateQuery()
            return
        }

        let daemonService = self.helperService()
        switch daemonService.status {
        case .enabled:
            break
        case .notRegistered:
            do {
                try daemonService.register()
            } catch {
                guard daemonService.status == .enabled else { return }
            }
        case .requiresApproval, .notFound:
            return
        @unknown default:
            return
        }

        guard daemonService.status == .enabled else { return }
        _ = try? await self.invokeStateQuery()
    }

    func applySystemProxy(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        try self.validateHost(host)

        do {
            try await self.applySystemProxyImpl(enabled: enabled, host: host, ports: ports)
        } catch {
            guard self.isHelperConnectionFailure(error),
                  self.isHelperBundledInMainApp(),
                  !self.isHelperInstalledInSystem()
            else { throw error }
            try await self.installHelperAsLegacyDaemon()
            try await self.applySystemProxyImpl(enabled: enabled, host: host, ports: ports)
        }
    }

    private func applySystemProxyImpl(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        if enabled {
            let resolvedPorts = try validateAndResolvePorts(ports, requiresEnabledPort: true)
            try await invokeMutation { helper, completion in
                helper.setSystemProxy(
                    host: host,
                    httpPort: resolvedPorts.httpPort,
                    httpsPort: resolvedPorts.httpsPort,
                    socksPort: resolvedPorts.socksPort,
                    completion: completion)
            }
        } else {
            try await self.invokeMutation { helper, completion in
                helper.clearSystemProxy(completion: completion)
            }
        }
    }

    func isSystemProxyEnabled() async throws -> Bool {
        do {
            try self.ensureHelperReadyForRead()
            return try await self.invokeStateQuery()
        } catch {
            guard self.isHelperConnectionFailure(error),
                  self.isHelperBundledInMainApp(),
                  !self.isHelperInstalledInSystem()
            else { throw error }
            try await self.installHelperAsLegacyDaemon()
            return try await self.invokeStateQuery()
        }
    }

    func readSystemProxyActiveDisplay() async throws -> String? {
        do {
            try self.ensureHelperReadyForRead()
            guard let target = try await self.invokeActiveTargetQuery() else {
                return nil
            }
            return self.formatProxyDisplay(host: target.host, port: target.port)
        } catch {
            guard self.isHelperConnectionFailure(error),
                  self.isHelperBundledInMainApp(),
                  !self.isHelperInstalledInSystem()
            else { throw error }
            try await self.installHelperAsLegacyDaemon()
            guard let target = try await self.invokeActiveTargetQuery() else {
                return nil
            }
            return self.formatProxyDisplay(host: target.host, port: target.port)
        }
    }

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        try self.validateHost(host)
        let resolvedPorts = try validateAndResolvePorts(ports, requiresEnabledPort: true)
        do {
            try self.ensureHelperReadyForRead()
            return try await self.invokeBooleanQuery { helper, completion in
                helper.isSystemProxyConfigured(
                    host: host,
                    httpPort: resolvedPorts.httpPort,
                    httpsPort: resolvedPorts.httpsPort,
                    socksPort: resolvedPorts.socksPort,
                    completion: completion)
            }
        } catch {
            guard self.isHelperConnectionFailure(error),
                  self.isHelperBundledInMainApp(),
                  !self.isHelperInstalledInSystem()
            else { throw error }
            try await self.installHelperAsLegacyDaemon()
            return try await self.invokeBooleanQuery { helper, completion in
                helper.isSystemProxyConfigured(
                    host: host,
                    httpPort: resolvedPorts.httpPort,
                    httpsPort: resolvedPorts.httpsPort,
                    socksPort: resolvedPorts.socksPort,
                    completion: completion)
            }
        }
    }

    func diagnoseCurrentHelper() async -> SystemProxyHelperDiagnosis {
        if !self.isHelperBundledInMainApp() {
            return .failed(message: self.helperFailureMessage(SystemProxyServiceError.helperNotBundled))
        }
        if self.isRunningFromReadOnlyVolume() {
            return .failed(message: self
                .helperFailureMessage(SystemProxyServiceError.helperRequiresInstallToApplications))
        }

        do {
            try self.ensureHelperReadyForRead()
            _ = try await self.invokeStateQuery()
            return .healthy
        } catch {
            return .failed(message: self.helperFailureMessage(error))
        }
    }

    func diagnoseAndRepairHelper() async -> SystemProxyHelperDiagnosis {
        let diagnosis = await self.diagnoseCurrentHelper()
        if case .healthy = diagnosis { return diagnosis }

        guard self.isHelperBundledInMainApp(), !self.isRunningFromReadOnlyVolume() else {
            return diagnosis
        }

        do {
            try await self.installHelperAsLegacyDaemon()
            _ = try await self.invokeStateQuery()
            return .healthy
        } catch {
            return .failed(message: self.helperFailureMessage(error))
        }
    }

    func installHelperManually() async -> SystemProxyHelperDiagnosis {
        await self.manualInstallHelper(forceReinstall: false)
    }

    func reinstallHelperManually() async -> SystemProxyHelperDiagnosis {
        await self.manualInstallHelper(forceReinstall: true)
    }

    private func manualInstallHelper(forceReinstall: Bool) async -> SystemProxyHelperDiagnosis {
        if !self.isHelperBundledInMainApp() {
            return .failed(message: SystemProxyServiceError.helperNotBundled.localizedDescription)
        }
        if self.isRunningFromReadOnlyVolume() {
            return .failed(message: SystemProxyServiceError.helperRequiresInstallToApplications.localizedDescription)
        }

        do {
            try await self.installOrReinstallHelper(forceReinstall: forceReinstall)
            _ = try await self.invokeStateQuery()
            return .healthy
        } catch {
            do {
                try await self.installHelperAsLegacyDaemon()
                _ = try await self.invokeStateQuery()
                return .healthy
            } catch let legacyError {
                return .failed(message: self.helperFailureMessage(legacyError))
            }
        }
    }

    private func validateHost(_ host: String) throws {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw SystemProxyServiceError.invalidHost
        }
    }

    private func validateAndResolvePorts(
        _ ports: SystemProxyPorts,
        requiresEnabledPort: Bool) throws -> (httpPort: Int, httpsPort: Int, socksPort: Int)
    {
        let httpPort = try normalizePort(ports.httpPort)
        let httpsPort = try normalizePort(ports.httpsPort)
        let socksPort = try normalizePort(ports.socksPort)

        if requiresEnabledPort, httpPort == 0, httpsPort == 0, socksPort == 0 {
            throw SystemProxyServiceError.invalidPort
        }

        return (httpPort: httpPort, httpsPort: httpsPort, socksPort: socksPort)
    }

    private func normalizePort(_ value: Int?) throws -> Int {
        guard let value else { return 0 }
        guard (1...65535).contains(value) else {
            throw SystemProxyServiceError.invalidPort
        }
        return value
    }

    private func ensureHelperReadyForWrite() async throws {
        guard self.isHelperBundledInMainApp() else {
            throw SystemProxyServiceError.helperNotBundled
        }
        guard !self.isRunningFromReadOnlyVolume() else {
            throw SystemProxyServiceError.helperRequiresInstallToApplications
        }

        if self.isHelperInstalledInSystem() { return }

        try self.validateHelperSigningRequirements()

        let daemonService = self.helperService()
        if daemonService.status == .enabled {
            return
        }
        if daemonService.status == .requiresApproval {
            throw SystemProxyServiceError.helperNeedsApproval
        }

        switch self.attemptHelperRegistration() {
        case .ready:
            return
        case .needsApproval:
            throw SystemProxyServiceError.helperNeedsApproval
        case let .blocked(message):
            throw SystemProxyServiceError.helperBlockedBySystemPolicy(message)
        case let .failed(message):
            throw SystemProxyServiceError.helperRegistrationFailed(message)
        }
    }

    private func ensureHelperReadyForRead() throws {
        guard self.isHelperBundledInMainApp() else {
            throw SystemProxyServiceError.helperNotBundled
        }
        guard !self.isRunningFromReadOnlyVolume() else {
            throw SystemProxyServiceError.helperRequiresInstallToApplications
        }

        if self.isHelperInstalledInSystem() { return }

        try self.validateHelperSigningRequirements()

        let daemonService = self.helperService()
        switch daemonService.status {
        case .enabled:
            return
        case .requiresApproval:
            throw SystemProxyServiceError.helperNeedsApproval
        case .notRegistered, .notFound:
            if self.isHelperInstalledInSystem() {
                throw SystemProxyServiceError.helperRegistrationFailed(
                    "Helper is installed but not enabled. Use Reinstall helper.")
            }
            throw SystemProxyServiceError.helperNotInstalled
        @unknown default:
            throw SystemProxyServiceError.helperRegistrationFailed(
                "Helper service not enabled. status=\(daemonService.status.rawValue)")
        }
    }

    private func isHelperBundledInMainApp() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let fileManager = FileManager.default

        let plistURL = bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
            .appendingPathComponent(ProxyHelperConstants.daemonPlistName, isDirectory: false)
        let helperURL = bundleURL
            .appendingPathComponent(ProxyHelperConstants.helperBundleProgram, isDirectory: false)

        return fileManager.fileExists(atPath: plistURL.path) && fileManager.fileExists(atPath: helperURL.path)
    }

    private func isRunningFromReadOnlyVolume() -> Bool {
        do {
            let values = try Bundle.main.bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
            return values.volumeIsReadOnly == true
        } catch {
            return false
        }
    }

    private func isHelperInstalledInSystem() -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: self.helperPlistInstallPath)
            && fileManager.fileExists(atPath: self.helperToolInstallPath)
    }

    private func isHelperConnectionFailure(_ error: Error) -> Bool {
        if let e = error as? SystemProxyServiceError, case .helperConnectionFailed = e {
            return true
        }
        return false
    }

    private func installHelperAsLegacyDaemon() async throws {
        guard Self.legacyInstallGate.tryAcquire() else {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            if self.isHelperInstalledInSystem() { return }
            throw SystemProxyServiceError.helperConnectionFailed("Legacy install already in progress.")
        }
        defer { Self.legacyInstallGate.release() }

        let daemonService = self.helperService()
        if daemonService.status == .enabled {
            try? await daemonService.unregister()
        }

        let helperSourcePath = Bundle.main.bundleURL
            .appendingPathComponent(ProxyHelperConstants.helperBundleProgram, isDirectory: false)
            .path
        let toolDest = self.helperToolInstallPath
        let plistDest = self.helperPlistInstallPath

        let legacyPlistXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(ProxyHelperConstants.machServiceName)</string>
            <key>MachServices</key>
            <dict>
                <key>\(ProxyHelperConstants.machServiceName)</key>
                <true/>
            </dict>
            <key>ProgramArguments</key>
            <array>
                <string>\(toolDest)</string>
            </array>
        </dict>
        </plist>
        """

        let tempPlist = NSTemporaryDirectory() + "\(ProxyHelperConstants.machServiceName).plist"
        try legacyPlistXML.write(toFile: tempPlist, atomically: true, encoding: .utf8)

        var cmds: [String] = []
        cmds.append("/bin/launchctl bootout system/\(ProxyHelperConstants.machServiceName) 2>/dev/null || true")
        cmds.append("/usr/bin/pkill -9 -x \(ProxyHelperConstants.machServiceName) 2>/dev/null || true")
        cmds.append("/bin/mkdir -p /Library/PrivilegedHelperTools")
        cmds.append("/bin/cp \(self.shellQuoted(helperSourcePath)) \(self.shellQuoted(toolDest))")
        cmds.append("/bin/chmod 755 \(self.shellQuoted(toolDest))")
        cmds.append("/usr/sbin/chown root:wheel \(self.shellQuoted(toolDest))")
        cmds.append("/bin/cp \(self.shellQuoted(tempPlist)) \(self.shellQuoted(plistDest))")
        cmds.append("/bin/chmod 644 \(self.shellQuoted(plistDest))")
        cmds.append("/usr/sbin/chown root:wheel \(self.shellQuoted(plistDest))")
        cmds.append("/bin/launchctl enable system/\(ProxyHelperConstants.machServiceName) 2>/dev/null || true")
        cmds.append("/bin/launchctl bootstrap system \(self.shellQuoted(plistDest))")

        let script = "do shell script \"\(self.appleScriptEscaped(cmds.joined(separator: " && ")))\" with administrator privileges"
        try self.runAppleScriptSynchronously(script)
        try? FileManager.default.removeItem(atPath: tempPlist)

        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func helperService() -> SMAppService {
        SMAppService.daemon(plistName: ProxyHelperConstants.daemonPlistName)
    }

    private func validateHelperSigningRequirements() throws {
        let appURL = Bundle.main.bundleURL
        let helperURL = appURL.appendingPathComponent(ProxyHelperConstants.helperBundleProgram, isDirectory: false)

        let appTeam = self.signingTeamIdentifier(at: appURL)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let helperTeam = self.signingTeamIdentifier(at: helperURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appHasTeam = !appTeam.isEmpty
        let helperHasTeam = !helperTeam.isEmpty

        // Allow ad-hoc/local builds where both app and helper have no TeamIdentifier.
        if !appHasTeam, !helperHasTeam {
            return
        }

        guard appHasTeam == helperHasTeam else {
            throw SystemProxyServiceError.helperInvalidSignature(
                "App/helper signing mode mismatch (one has TeamIdentifier, the other does not).")
        }

        guard appTeam == helperTeam else {
            throw SystemProxyServiceError.helperInvalidSignature(
                "App and helper TeamIdentifier mismatch (\(appTeam) != \(helperTeam)).")
        }
    }

    private func signingTeamIdentifier(at url: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info) == errSecSuccess,
            let dict = info as? [String: Any]
        else { return nil }

        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private func invokeStateQuery() async throws -> Bool {
        try await self.invokeBooleanQuery { helper, completion in
            helper.getSystemProxyState(completion: completion)
        }
    }

    private func isLikelyBlockedBySystemPolicy(_ error: Error) -> Bool {
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("operation not permitted")
            || normalized.contains("disallowed")
            || normalized.contains("denied")
            || normalized.contains("launch constraint")
            || normalized.contains("background item")
    }

    private func attemptHelperRegistration() -> HelperRegistrationResult {
        let daemonService = self.helperService()
        if daemonService.status == .enabled {
            return .ready
        }

        do {
            try daemonService.register()
        } catch {
            if daemonService.status == .enabled {
                return .ready
            }
            if daemonService.status == .requiresApproval {
                if self.isLikelyBlockedBySystemPolicy(error) {
                    return .blocked(error.localizedDescription)
                }
                return .needsApproval
            }
            if self.isLikelyBlockedBySystemPolicy(error) {
                return .blocked(error.localizedDescription)
            }
            return .failed(error.localizedDescription)
        }

        if daemonService.status == .enabled {
            return .ready
        }
        if daemonService.status == .requiresApproval {
            return .needsApproval
        }
        return .failed("Service remains unavailable after register call. status=\(daemonService.status.rawValue)")
    }

    private func installOrReinstallHelper(forceReinstall: Bool) async throws {
        let daemonService = self.helperService()
        if forceReinstall || daemonService.status == .enabled {
            try? await daemonService.unregister()
        }

        try self.cleanupInstalledHelper(forceReinstall: forceReinstall)

        switch self.attemptHelperRegistration() {
        case .ready:
            return
        case .needsApproval:
            throw SystemProxyServiceError.helperNeedsApproval
        case let .blocked(message):
            throw SystemProxyServiceError.helperBlockedBySystemPolicy(message)
        case let .failed(message):
            throw SystemProxyServiceError.helperRegistrationFailed(message)
        }
    }

    private func cleanupInstalledHelper(forceReinstall: Bool) throws {
        let escapedPlist = self.shellQuoted(self.helperPlistInstallPath)
        let escapedTool = self.shellQuoted(self.helperToolInstallPath)

        var commands: [String] = []
        commands.append("/bin/launchctl bootout system/\(ProxyHelperConstants.machServiceName) >/dev/null 2>&1 || true")
        if forceReinstall {
            commands.append("/bin/launchctl bootout system \(escapedPlist) >/dev/null 2>&1 || true")
            commands
                .append("/bin/launchctl disable system/\(ProxyHelperConstants.machServiceName) >/dev/null 2>&1 || true")
            commands.append("/bin/launchctl remove \(ProxyHelperConstants.machServiceName) >/dev/null 2>&1 || true")
            commands.append("/usr/bin/pkill -9 -x com.clashbar.helper >/dev/null 2>&1 || true")
            commands.append("/bin/rm -f \(escapedPlist)")
            commands.append("/bin/rm -f \(escapedTool)")
        }
        guard !commands.isEmpty else { return }

        let shellCommand = commands.joined(separator: " && ")
        let appleScript = "do shell script \"\(self.appleScriptEscaped(shellCommand))\" with administrator privileges"
        try self.runAppleScriptSynchronously(appleScript)
    }

    private func invokeMutation(
        _ invoke: @escaping (ProxyHelperProtocol, @escaping (Bool, String?) -> Void) -> Void) async throws
    {
        try await self.ensureHelperReadyForWrite()
        try await self.invokeHelper { helper, completion in
            invoke(helper) { success, message in
                if success {
                    completion(.success(()))
                    return
                }
                completion(.failure(SystemProxyServiceError.helperOperationFailed(message ?? "Unknown helper error.")))
            }
        }
    }

    private func invokeBooleanQuery(
        _ invoke: @escaping (ProxyHelperProtocol, @escaping (Bool, Bool, String?) -> Void) -> Void) async throws -> Bool
    {
        try await self.invokeHelper { helper, completion in
            invoke(helper) { success, boolValue, message in
                if success {
                    completion(.success(boolValue))
                    return
                }
                completion(.failure(SystemProxyServiceError.helperOperationFailed(message ?? "Unknown helper error.")))
            }
        }
    }

    private func invokeActiveTargetQuery() async throws -> (host: String, port: Int)? {
        try await self.invokeHelper { helper, completion in
            helper.getSystemProxyActiveTarget { success, host, port, message in
                if success {
                    guard let host, !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, port > 0 else {
                        completion(.success(nil))
                        return
                    }
                    completion(.success((host: host, port: port)))
                    return
                }
                completion(.failure(SystemProxyServiceError.helperOperationFailed(message ?? "Unknown helper error.")))
            }
        }
    }

    private func formatProxyDisplay(host: String, port: Int) -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]:\(port)"
        }
        return "\(trimmedHost):\(port)"
    }

    private func helperFailureMessage(_ error: Error) -> String {
        if let serviceError = error as? SystemProxyServiceError {
            return serviceError.localizedDescription
        }
        return error.localizedDescription
    }

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            [self.stderr, self.stdout]
                .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown command error."
        }
    }

    private func runProcessSynchronously(executable: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SystemProxyServiceError.helperOperationFailed(error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func runAppleScriptSynchronously(_ script: String) throws {
        let result = try self.runProcessSynchronously(executable: "/usr/bin/osascript", arguments: ["-e", script])
        guard result.exitCode == 0 else {
            let message = result.combinedOutput
            if message.lowercased().contains("user canceled") {
                throw SystemProxyServiceError.helperOperationFailed("Administrator authorization was cancelled.")
            }
            throw SystemProxyServiceError.helperOperationFailed(message)
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func invokeHelper<Value: Sendable>(
        _ invoke: @escaping (ProxyHelperProtocol, @escaping (Result<Value, Error>) -> Void) -> Void) async throws
        -> Value
    {
        try await withCheckedThrowingContinuation { continuation in
            let connection = self.makeConnection()
            let box = ContinuationBox<Value>(continuation)
            let timeoutWorkItem = DispatchWorkItem {
                connection.invalidate()
                box.resume(
                    with: .failure(
                        SystemProxyServiceError.helperConnectionFailed("Helper response timed out.")))
            }
            let timeoutInterval = DispatchTimeInterval.nanoseconds(Int(self.helperResponseTimeoutNanoseconds))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + timeoutInterval,
                execute: timeoutWorkItem)

            guard let helper = connection.remoteObjectProxyWithErrorHandler({ error in
                timeoutWorkItem.cancel()
                connection.invalidate()
                box.resume(with: .failure(SystemProxyServiceError.helperConnectionFailed(error.localizedDescription)))
            }) as? ProxyHelperProtocol else {
                timeoutWorkItem.cancel()
                connection.invalidate()
                box
                    .resume(with: .failure(SystemProxyServiceError
                            .helperConnectionFailed("Unable to create XPC proxy.")))
                return
            }

            invoke(helper) { result in
                timeoutWorkItem.cancel()
                defer { connection.invalidate() }
                box.resume(with: result)
            }
        }
    }

    func clearSystemProxyBlocking(timeout: TimeInterval = 2.0) {
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let connection = NSXPCConnection(
                machServiceName: ProxyHelperConstants.machServiceName,
                options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: ProxyHelperProtocol.self)
            connection.activate()

            guard let helper = connection.remoteObjectProxyWithErrorHandler({ _ in
                semaphore.signal()
            }) as? ProxyHelperProtocol else {
                connection.invalidate()
                semaphore.signal()
                return
            }

            helper.clearSystemProxy { _, _ in
                connection.invalidate()
                semaphore.signal()
            }
        }

        _ = semaphore.wait(timeout: .now() + timeout)
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: ProxyHelperConstants.machServiceName,
            options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: ProxyHelperProtocol.self)
        connection.activate()
        return connection
    }
}
