import Foundation
import ProxyHelperShared
import Security
import SystemConfiguration

private enum ProxyHelperError: LocalizedError {
    case invalidHost
    case invalidPort
    case missingPreferences
    case missingCurrentSet
    case noEnabledNetworkServices
    case systemConfigurationFailure(action: String, code: Int32, detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Invalid proxy host"
        case .invalidPort:
            "Invalid proxy port"
        case .missingPreferences:
            "Unable to access system network preferences"
        case .missingCurrentSet:
            "Unable to find current network set"
        case .noEnabledNetworkServices:
            "No enabled network services found"
        case let .systemConfigurationFailure(action, _, detail):
            "\(action) failed: \(detail)"
        }
    }
}

private final class SystemProxyConfigurator {
    private struct ProxyEntrySpec {
        let enableKey: String
        let hostKey: String
        let portKey: String
    }

    private static let proxyEntrySpecs: [ProxyEntrySpec] = [
        ProxyEntrySpec(
            enableKey: kSCPropNetProxiesHTTPEnable as String,
            hostKey: kSCPropNetProxiesHTTPProxy as String,
            portKey: kSCPropNetProxiesHTTPPort as String),
        ProxyEntrySpec(
            enableKey: kSCPropNetProxiesHTTPSEnable as String,
            hostKey: kSCPropNetProxiesHTTPSProxy as String,
            portKey: kSCPropNetProxiesHTTPSPort as String),
        ProxyEntrySpec(
            enableKey: kSCPropNetProxiesSOCKSEnable as String,
            hostKey: kSCPropNetProxiesSOCKSProxy as String,
            portKey: kSCPropNetProxiesSOCKSPort as String),
    ]

    func setSystemProxy(host: String, httpPort: Int, httpsPort: Int, socksPort: Int) throws {
        try self.validate(host: host)
        let ports = try validatedPorts(
            httpPort: httpPort,
            httpsPort: httpsPort,
            socksPort: socksPort,
            requiresEnabledProxy: true)

        try withMutableProxyProtocols { protocols in
            for proxyProtocol in protocols {
                var config = self.configuration(for: proxyProtocol)
                let portValues = [ports.httpPort, ports.httpsPort, ports.socksPort]
                for (spec, portValue) in zip(Self.proxyEntrySpecs, portValues) {
                    self.configureProxyEntry(
                        config: &config,
                        spec: spec,
                        host: host,
                        port: portValue)
                }

                guard SCNetworkProtocolSetConfiguration(proxyProtocol, config as CFDictionary) else {
                    throw self.systemConfigurationError(action: "Set proxy configuration")
                }
            }
        }
    }

    func clearSystemProxy() throws {
        try self.withMutableProxyProtocols { protocols in
            for proxyProtocol in protocols {
                var config = self.configuration(for: proxyProtocol)
                for spec in Self.proxyEntrySpecs {
                    self.configureProxyEntry(config: &config, spec: spec, host: "", port: 0)
                }

                guard SCNetworkProtocolSetConfiguration(proxyProtocol, config as CFDictionary) else {
                    throw self.systemConfigurationError(action: "Clear proxy configuration")
                }
            }
        }
    }

    func isSystemProxyEnabled() throws -> Bool {
        let preferences = try makePreferences()
        let protocols = try proxyProtocols(from: preferences)

        for proxyProtocol in protocols {
            let config = self.configuration(for: proxyProtocol)
            if Self.proxyEntrySpecs.contains(where: { isEnabled(config: config, key: $0.enableKey) }) {
                return true
            }
        }

        return false
    }

    func isSystemProxyConfigured(host: String, httpPort: Int, httpsPort: Int, socksPort: Int) throws -> Bool {
        try self.validate(host: host)
        let ports = try validatedPorts(
            httpPort: httpPort,
            httpsPort: httpsPort,
            socksPort: socksPort,
            requiresEnabledProxy: true)

        let preferences = try makePreferences()
        let protocols = try proxyProtocols(from: preferences)
        let expectedPorts = [ports.httpPort, ports.httpsPort, ports.socksPort]

        for proxyProtocol in protocols {
            let config = self.configuration(for: proxyProtocol)
            for (spec, expectedPort) in zip(Self.proxyEntrySpecs, expectedPorts) {
                guard self.proxyMatchesExpectedState(
                    config: config,
                    spec: spec,
                    expectedHost: host,
                    expectedPort: expectedPort)
                else {
                    return false
                }
            }
        }

        return true
    }

    func systemProxyActiveTarget() throws -> (host: String, port: Int)? {
        let preferences = try makePreferences()
        let protocols = try proxyProtocols(from: preferences)

        for proxyProtocol in protocols {
            let config = self.configuration(for: proxyProtocol)
            for spec in Self.proxyEntrySpecs {
                guard self.isEnabled(config: config, key: spec.enableKey) else {
                    continue
                }
                let host = (config[spec.hostKey] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !host.isEmpty else {
                    continue
                }
                guard let port = self.intValue(config[spec.portKey]), port > 0 else {
                    continue
                }
                return (host: host, port: port)
            }
        }

        return nil
    }

    func systemProxyExceptions() throws -> [String] {
        let preferences = try makePreferences()
        let protocols = try proxyProtocols(from: preferences)
        var aggregated: [String] = []
        var seen: Set<String> = []

        for proxyProtocol in protocols {
            let config = self.configuration(for: proxyProtocol)
            for value in self.exceptionsList(from: config) {
                let key = value.lowercased()
                guard seen.insert(key).inserted else { continue }
                aggregated.append(value)
            }
        }

        return aggregated
    }

    func setSystemProxyExceptions(_ exceptions: [String]) throws {
        let normalized = self.normalizedExceptions(exceptions)

        try self.withMutableProxyProtocols { protocols in
            for proxyProtocol in protocols {
                var config = self.configuration(for: proxyProtocol)
                config[kSCPropNetProxiesExceptionsList as String] = normalized
                config[kSCPropNetProxiesExcludeSimpleHostnames as String] = 0

                guard SCNetworkProtocolSetConfiguration(proxyProtocol, config as CFDictionary) else {
                    throw self.systemConfigurationError(action: "Set proxy exceptions")
                }
            }
        }
    }

    private func validate(host: String) throws {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw ProxyHelperError.invalidHost
        }
    }

    private func validatedPorts(
        httpPort: Int,
        httpsPort: Int,
        socksPort: Int,
        requiresEnabledProxy: Bool) throws -> (httpPort: Int, httpsPort: Int, socksPort: Int)
    {
        let httpPort = try validatedPort(httpPort)
        let httpsPort = try validatedPort(httpsPort)
        let socksPort = try validatedPort(socksPort)

        if requiresEnabledProxy, httpPort == 0, httpsPort == 0, socksPort == 0 {
            throw ProxyHelperError.invalidPort
        }

        return (httpPort: httpPort, httpsPort: httpsPort, socksPort: socksPort)
    }

    private func validatedPort(_ value: Int) throws -> Int {
        guard (0...65535).contains(value) else {
            throw ProxyHelperError.invalidPort
        }
        return value
    }

    private func configureProxyEntry(
        config: inout [String: Any],
        spec: ProxyEntrySpec,
        host: String,
        port: Int)
    {
        if port > 0 {
            config[spec.enableKey] = 1
            config[spec.hostKey] = host
            config[spec.portKey] = port
        } else {
            config[spec.enableKey] = 0
            config[spec.hostKey] = ""
            config[spec.portKey] = 0
        }
    }

    private func withMutableProxyProtocols(_ update: ([SCNetworkProtocol]) throws -> Void) throws {
        let preferences = try makePreferences()

        guard SCPreferencesLock(preferences, true) else {
            throw self.systemConfigurationError(action: "Lock system preferences")
        }
        defer { SCPreferencesUnlock(preferences) }

        let protocols = try proxyProtocols(from: preferences)
        try update(protocols)

        guard SCPreferencesCommitChanges(preferences) else {
            throw self.systemConfigurationError(action: "Commit proxy preferences")
        }
        guard SCPreferencesApplyChanges(preferences) else {
            throw self.systemConfigurationError(action: "Apply proxy preferences")
        }
    }

    private func makePreferences() throws -> SCPreferences {
        guard let preferences = SCPreferencesCreate(nil, "com.clashbar.helper" as CFString, nil) else {
            throw ProxyHelperError.missingPreferences
        }
        return preferences
    }

    private func proxyProtocols(from preferences: SCPreferences) throws -> [SCNetworkProtocol] {
        guard let currentSet = SCNetworkSetCopyCurrent(preferences) else {
            throw ProxyHelperError.missingCurrentSet
        }

        guard let services = SCNetworkSetCopyServices(currentSet) as? [SCNetworkService] else {
            throw ProxyHelperError.noEnabledNetworkServices
        }

        let protocols = services.compactMap { service -> SCNetworkProtocol? in
            guard SCNetworkServiceGetEnabled(service) else {
                return nil
            }
            return SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies)
        }

        guard !protocols.isEmpty else {
            throw ProxyHelperError.noEnabledNetworkServices
        }

        return protocols
    }

    private func configuration(for proxyProtocol: SCNetworkProtocol) -> [String: Any] {
        (SCNetworkProtocolGetConfiguration(proxyProtocol) as? [String: Any]) ?? [:]
    }

    private func exceptionsList(from config: [String: Any]) -> [String] {
        let key = kSCPropNetProxiesExceptionsList as String

        if let values = config[key] as? [String] {
            return self.normalizedExceptions(values)
        }

        if let values = config[key] as? [NSString] {
            return self.normalizedExceptions(values.map(String.init))
        }

        if let values = config[key] as? [Any] {
            let strings = values.compactMap { value -> String? in
                if let string = value as? String {
                    return string
                }
                if let string = value as? NSString {
                    return String(string)
                }
                return nil
            }
            return self.normalizedExceptions(strings)
        }

        return []
    }

    private func normalizedExceptions(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }

    private func isEnabled(config: [String: Any], key: String) -> Bool {
        if let value = config[key] as? NSNumber {
            return value.intValue != 0
        }
        if let value = config[key] as? Int {
            return value != 0
        }
        if let value = config[key] as? Bool {
            return value
        }
        return false
    }

    private func proxyHostAndPortMatch(
        config: [String: Any],
        spec: ProxyEntrySpec,
        expectedHost: String,
        expectedPort: Int) -> Bool
    {
        let currentHost = (config[spec.hostKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let normalizedExpectedHost = expectedHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard currentHost == normalizedExpectedHost else {
            return false
        }

        return self.intValue(config[spec.portKey]) == expectedPort
    }

    private func proxyMatchesExpectedState(
        config: [String: Any],
        spec: ProxyEntrySpec,
        expectedHost: String,
        expectedPort: Int) -> Bool
    {
        let enabled = self.isEnabled(config: config, key: spec.enableKey)
        if expectedPort == 0 {
            return !enabled
        }
        guard enabled else {
            return false
        }
        return self.proxyHostAndPortMatch(
            config: config,
            spec: spec,
            expectedHost: expectedHost,
            expectedPort: expectedPort)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func systemConfigurationError(action: String) -> ProxyHelperError {
        let code = SCError()
        let detail = String(cString: SCErrorString(code))
        return .systemConfigurationFailure(action: action, code: code, detail: detail)
    }
}

private final class DNSConfigurator {
    private static let backupFilePath = "/var/db/clashbar/original-dns.txt"

    private struct HardwarePortResult {
        let port: String
        let interface: String
    }

    private struct DNSState {
        let port: String
        let servers: String
    }

    func setDNSServers(dnsServer: String) throws {
        guard Self.isValidIPv4(dnsServer) else {
            throw ProxyHelperError.systemConfigurationFailure(
                action: "Set DNS servers",
                code: 0,
                detail: "Invalid DNS server address: \(dnsServer)")
        }

        let ports = try detectPhysicalHardwarePorts()
        guard !ports.isEmpty else {
            throw ProxyHelperError.systemConfigurationFailure(
                action: "Set DNS servers",
                code: 0,
                detail: "No physical network service found")
        }

        let currentStates = try ports.map { port in
            DNSState(port: port.port, servers: try readCurrentDNS(port: port.port))
        }

        let backupFile = Self.backupFilePath
        if !FileManager.default.fileExists(atPath: backupFile) {
            let backup = currentStates.map { state in
                "\(state.port)|\(state.servers)"
            }.joined(separator: "\n")
            let dir = (backupFile as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try backup.write(toFile: backupFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupFile)
        }

        var appliedStates: [DNSState] = []
        do {
            for state in currentStates {
                try applyDNSServers(dnsServer, port: state.port)
                appliedStates.append(state)
            }
        } catch {
            try? rollbackDNSServers(appliedStates)
            throw error
        }
    }

    func restoreDNSServers() throws {
        let backupFile = Self.backupFilePath
        guard FileManager.default.fileExists(atPath: backupFile) else { return }

        let backupContent = try String(contentsOfFile: backupFile, encoding: .utf8)

        for line in backupContent.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let state = DNSState(port: String(parts[0]), servers: String(parts[1]))
            try applyDNSState(state)
        }

        try? FileManager.default.removeItem(atPath: backupFile)
    }

    private func detectPhysicalHardwarePorts() throws -> [HardwarePortResult] {
        let listResult = runProcessSynchronously(
            executable: "/usr/sbin/networksetup",
            arguments: ["-listnetworkserviceorder"])

        guard listResult.exitCode == 0 else {
            let detail = listResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ProxyHelperError.systemConfigurationFailure(
                action: "List network service order",
                code: listResult.exitCode,
                detail: detail.isEmpty
                    ? "networksetup -listnetworkserviceorder failed with no output"
                    : detail)
        }

        var results: [HardwarePortResult] = []
        let lines = listResult.stdout.components(separatedBy: "\n")
        var currentPort: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("("), let range = trimmed.range(of: ") ") {
                currentPort = String(trimmed[range.upperBound...])
            }
            if trimmed.hasPrefix("(Hardware Port:"), let port = currentPort {
                if let deviceRange = trimmed.range(of: "Device: ") {
                    let device = String(trimmed[deviceRange.upperBound...])
                        .trimmingCharacters(in: CharacterSet(charactersIn: ")"))
                        .trimmingCharacters(in: .whitespaces)
                    if isPhysicalInterface(device) {
                        results.append(HardwarePortResult(port: port, interface: device))
                    }
                }
            }
        }
        return results
    }

    private func isPhysicalInterface(_ device: String) -> Bool {
        let normalized = device.lowercased()
        if normalized.hasPrefix("en") { return true }
        if normalized.hasPrefix("bridge") { return true }
        return false
    }

    private func readCurrentDNS(port: String) throws -> String {
        let result = runProcessSynchronously(
            executable: "/usr/sbin/networksetup",
            arguments: ["-getdnsservers", port])

        guard result.exitCode == 0 else {
            throw ProxyHelperError.systemConfigurationFailure(
                action: "Read DNS servers for \(port)",
                code: result.exitCode,
                detail: result.combinedOutput)
        }

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("There aren't any DNS Servers set on") {
            return "empty"
        }
        guard !output.isEmpty else { return "empty" }
        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func applyDNSServers(_ dnsServer: String, port: String) throws {
        let result = runProcessSynchronously(
            executable: "/usr/sbin/networksetup",
            arguments: ["-setdnsservers", port, dnsServer])

        guard result.exitCode == 0 else {
            throw ProxyHelperError.systemConfigurationFailure(
                action: "Set DNS servers",
                code: result.exitCode,
                detail: result.combinedOutput)
        }
    }

    private func rollbackDNSServers(_ states: [DNSState]) throws {
        for state in states.reversed() {
            try applyDNSState(state)
        }
    }

    private func applyDNSState(_ state: DNSState) throws {
        let args: [String]
        if state.servers.isEmpty || state.servers == "empty" {
            args = ["-setdnsservers", state.port, "empty"]
        } else {
            args = ["-setdnsservers", state.port]
                + state.servers.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        }

        let result = runProcessSynchronously(executable: "/usr/sbin/networksetup", arguments: args)
        guard result.exitCode == 0 else {
            throw ProxyHelperError.systemConfigurationFailure(
                action: "Restore DNS for \(state.port)",
                code: result.exitCode,
                detail: result.combinedOutput)
        }
    }

    private static func isValidIPv4(_ address: String) -> Bool {
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let octet = Int(part), (0...255).contains(octet) else { return false }
            return part == String(octet)  // reject leading zeros like "01"
        }
    }

    private func runProcessSynchronously(executable: String, arguments: [String]) -> ProcessResult {
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
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
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

private final class ProxyHelperService: NSObject, ProxyHelperProtocol {
    private let configurator = SystemProxyConfigurator()
    private let dnsConfigurator = DNSConfigurator()

    func ping(completion: @escaping (Bool, String?) -> Void) {
        completion(true, nil)
    }

    func setSystemProxy(
        host: String,
        httpPort: Int,
        httpsPort: Int,
        socksPort: Int,
        completion: @escaping (Bool, String?) -> Void)
    {
        do {
            try self.configurator.setSystemProxy(
                host: host,
                httpPort: httpPort,
                httpsPort: httpsPort,
                socksPort: socksPort)
            completion(true, nil)
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func clearSystemProxy(completion: @escaping (Bool, String?) -> Void) {
        do {
            try self.configurator.clearSystemProxy()
            completion(true, nil)
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func getSystemProxyState(completion: @escaping (Bool, Bool, String?) -> Void) {
        do {
            let enabled = try configurator.isSystemProxyEnabled()
            completion(true, enabled, nil)
        } catch {
            completion(false, false, error.localizedDescription)
        }
    }

    func getSystemProxyActiveTarget(completion: @escaping (Bool, String?, Int, String?) -> Void) {
        do {
            let target = try configurator.systemProxyActiveTarget()
            completion(true, target?.host, target?.port ?? 0, nil)
        } catch {
            completion(false, nil, 0, error.localizedDescription)
        }
    }

    func isSystemProxyConfigured(
        host: String,
        httpPort: Int,
        httpsPort: Int,
        socksPort: Int,
        completion: @escaping (Bool, Bool, String?) -> Void)
    {
        do {
            let configured = try configurator.isSystemProxyConfigured(
                host: host,
                httpPort: httpPort,
                httpsPort: httpsPort,
                socksPort: socksPort)
            completion(true, configured, nil)
        } catch {
            completion(false, false, error.localizedDescription)
        }
    }

    func getSystemProxyExceptions(completion: @escaping (Bool, String?, String?) -> Void) {
        do {
            let exceptions = try self.configurator.systemProxyExceptions()
            completion(true, exceptions.joined(separator: "\n"), nil)
        } catch {
            completion(false, nil, error.localizedDescription)
        }
    }

    func setSystemProxyExceptions(serializedExceptions: String, completion: @escaping (Bool, String?) -> Void) {
        do {
            let exceptions = serializedExceptions.components(separatedBy: .newlines)
            try self.configurator.setSystemProxyExceptions(exceptions)
            completion(true, nil)
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func setDNSServers(dnsServer: String, completion: @escaping (Bool, String?) -> Void) {
        do {
            try dnsConfigurator.setDNSServers(dnsServer: dnsServer)
            completion(true, nil)
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func restoreDNSServers(completion: @escaping (Bool, String?) -> Void) {
        do {
            try dnsConfigurator.restoreDNSServers()
            completion(true, nil)
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}

private final class ProxyHelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = ProxyHelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ProxyHelperProtocol.self)
        newConnection.exportedObject = self.service
        newConnection.resume()
        return true
    }
}

@main
private struct ClashBarProxyHelperMain {
    static func main() {
        let delegate = ProxyHelperListenerDelegate()
        let listener = NSXPCListener(machServiceName: ProxyHelperConstants.machServiceName)
        listener.delegate = delegate
        listener.setConnectionCodeSigningRequirement(self.buildClientRequirement())
        listener.resume()
        dispatchMain()
    }

    private static func buildClientRequirement() -> String {
        let base = ProxyHelperConstants.allowedClientRequirement
        guard let teamID = selfTeamIdentifier(), !teamID.isEmpty else {
            return base
        }
        return "\(base) and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    private static func selfTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
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
}
