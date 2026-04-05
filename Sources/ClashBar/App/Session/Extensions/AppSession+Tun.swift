import Foundation

enum TunModeError: LocalizedError {
    case runtimeStateMismatch(expected: Bool)

    var errorDescription: String? {
        switch self {
        case let .runtimeStateMismatch(expected):
            "TUN runtime state mismatch. expected=\(expected)"
        }
    }
}

@MainActor
extension AppSession {
    private var validateTunPermissionsUseCase: ValidateTunPermissionsUseCase {
        ValidateTunPermissionsUseCase(repository: self.tunPermissionRepository)
    }

    private var grantTunPermissionsUseCase: GrantTunPermissionsUseCase {
        GrantTunPermissionsUseCase(repository: self.tunPermissionRepository)
    }

    func toggleTunMode(_ enabled: Bool) async {
        guard !isTunSyncing else { return }
        guard enabled != isTunEnabled else { return }

        isTunSyncing = true
        defer { isTunSyncing = false }

        do {
            if enabled, !self.isRemoteTarget {
                try await self.ensureTunPermissions(requestIfMissing: true)
            }

            guard self.isRemoteTarget || self.isRuntimeRunning else { return }
            try await self.applyTunRuntimeChange(enabled: enabled)

            let config = try await fetchRuntimeConfigSnapshot()
            let actualState = config.tunEnabled ?? false
            isTunEnabled = actualState
            persistEditableSettingsSnapshot()

            if actualState == enabled {
                appendLog(
                    level: "info",
                    message: tr("log.tun.toggled", enabled ? tr("log.tun.enabled") : tr("log.tun.disabled")))
            } else {
                appendLog(
                    level: "error",
                    message: tr("log.tun.toggle_failed", tr("app.tun.error.runtime_state_mismatch")))
            }
        } catch {
            appendLog(level: "error", message: tr("log.tun.toggle_failed", self.tunErrorMessage(error)))
            await self.refreshTunStatusFromRuntimeConfig()
        }
    }

    func prepareTunOverlayForCoreStartup(_ overlay: EditableSettingsSnapshot) async throws -> EditableSettingsSnapshot {
        guard overlay.tunEnabled else { return overlay }

        do {
            // On app updates, bundled mihomo may lose setuid/root ownership.
            // Request permission proactively to avoid silently disabling TUN on startup.
            try await self.ensureTunPermissions(requestIfMissing: true)
            return overlay
        } catch {
            isTunEnabled = false
            persistEditableSettingsSnapshot()
            appendLog(level: "warning", message: tr("log.tun.startup_disabled"))
            return overlay.withTunEnabled(false)
        }
    }

    func validateTunPermissionsOnStartup() async {
        guard isTunEnabled else { return }
        do {
            try await self.ensureTunPermissions(requestIfMissing: false)
        } catch {
            if isRuntimeRunning {
                try? await self.patchTunConfig(enable: false)
            }
            isTunEnabled = false
            persistEditableSettingsSnapshot()
            appendLog(level: "warning", message: tr("log.tun.startup_disabled"))
        }
    }

    func tunErrorMessage(_ error: Error) -> String {
        if let permissionError = error as? TunPermissionServiceError {
            switch permissionError {
            case .coreBinaryNotFound, .coreBinaryNotExecutable:
                return tr("app.tun.error.binary_not_found", workingDirectoryManager.coreDirectoryURL.path)
            case .permissionMissing:
                return tr("app.tun.error.permission_missing")
            case .authorizationCancelled:
                return tr("app.tun.error.authorization_cancelled")
            case let .authorizationFailed(message):
                return tr("app.tun.error.authorization_failed", message)
            case .permissionVerificationFailed:
                return tr("app.tun.error.permission_verify_failed")
            }
        }

        if let tunModeError = error as? TunModeError {
            switch tunModeError {
            case .runtimeStateMismatch:
                return tr("app.tun.error.runtime_state_mismatch")
            }
        }

        if let apiError = error as? APIError,
           case .statusCode = apiError
        {
            return tr("app.tun.error.patch_failed", apiError.localizedDescription)
        }

        return error.localizedDescription
    }

    func resolvedMihomoBinaryPath() -> String? {
        if let detected = coreRepository.detectedBinaryPath,
           !detected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return detected
        }

        let current = mihomoBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || current == "-" {
            return nil
        }
        return current
    }

    func ensureTunPermissions(requestIfMissing: Bool) async throws {
        guard let binaryPath = resolvedMihomoBinaryPath() else {
            throw TunPermissionServiceError.coreBinaryNotFound
        }

        do {
            try self.validateTunPermissionsUseCase.execute(binaryPath: binaryPath)
        } catch TunPermissionServiceError.permissionMissing {
            guard requestIfMissing else {
                throw TunPermissionServiceError.permissionMissing
            }
            appendLog(level: "info", message: tr("log.tun.permission_requesting"))
            try await self.grantTunPermissionsUseCase.execute(binaryPath: binaryPath)
            appendLog(level: "info", message: tr("log.tun.permission_granted"))
        }
    }

    func verifyTunAfterOverlayIfNeeded(overlay: EditableSettingsSnapshot) async {
        guard overlay.tunEnabled, isRuntimeRunning else {
            await self.restoreTunDNSSafely(context: "cleanup stale")
            return
        }
        guard pendingCoreFeatureRecoveryState == nil else { return }

        do {
            let config = try await fetchRuntimeConfigSnapshot()
            if config.tunEnabled == true {
                isTunEnabled = true
                // patchTunConfig was skipped, so DNS was never set
                await self.setTunDNSSafely(context: "on startup")
                persistEditableSettingsSnapshot()
                return
            }

            try await self.applyTunRuntimeChange(enabled: true)
            isTunEnabled = true
            persistEditableSettingsSnapshot()
            appendLog(level: "info", message: tr("log.tun.toggled", tr("log.tun.enabled")))
        } catch {
            appendLog(level: "error", message: tr("log.tun.toggle_failed", self.tunErrorMessage(error)))
        }
    }

    func applyTunRuntimeChange(enabled: Bool) async throws {
        guard self.isRemoteTarget || self.isRuntimeRunning else { return }
        try await self.patchTunConfig(enable: enabled)

        do {
            try await self.verifyTunRuntimeState(expectedEnabled: enabled)
        } catch {
            if enabled {
                await self.restoreTunDNSSafely(context: "after enable failure")
            }
            throw error
        }
    }

    func verifyTunRuntimeState(expectedEnabled: Bool) async throws {
        let config = try await fetchRuntimeConfigSnapshot()
        let actual = config.tunEnabled ?? false
        if actual != expectedEnabled {
            throw TunModeError.runtimeStateMismatch(expected: expectedEnabled)
        }
    }

    func patchTunConfig(enable: Bool) async throws {
        if enable {
            // Set DNS BEFORE enabling TUN so that route -n get default still returns
            // the physical interface. This also covers the case where no en* service
            // is found by falling back to the default route approach.
            try await self.setTunDNSForEnable()
        }

        let client = try clientOrThrow()
        var tunBody: [String: JSONValue] = ["enable": .bool(enable)]

        if enable, await !self.selectedConfigDeclaresTunStack() {
            tunBody["stack"] = .string("mixed")
        }

        var body: [String: JSONValue] = ["tun": .object(tunBody)]
        if enable {
            body["dns"] = .object(["enable": .bool(true)])
        }

        do {
            try await self.makePatchRuntimeConfigUseCase(using: client).execute(body: body)
        } catch {
            if enable {
                await self.restoreTunDNSSafely(context: "after patch failure")
            }
            throw error
        }

        if !enable {
            // Restore DNS AFTER disabling TUN, once the default route is back on the physical interface.
            try await self.restoreTunDNS()
        }
    }

    private static let defaultTunDNSServer = "198.18.0.1"

    func setTunDNSForEnable() async throws {
        let dnsServer = await self.resolvedTunDNSServer()
        try await self.systemProxyRepository.setDNSServers(dnsServer: dnsServer)
        appendLog(level: "info", message: "TUN DNS set to \(dnsServer)")
    }

    func restoreTunDNS() async throws {
        try await self.systemProxyRepository.restoreDNSServers()
        appendLog(level: "info", message: "TUN DNS restored")
    }

    func restoreTunDNSSafely(context: String) async {
        do {
            try await self.restoreTunDNS()
        } catch {
            appendLog(
                level: "warning",
                message: "Failed to restore TUN DNS \(context): \(error.localizedDescription)")
        }
    }

    func setTunDNSSafely(context: String) async {
        do {
            try await self.setTunDNSForEnable()
        } catch {
            appendLog(
                level: "warning",
                message: "Failed to set TUN DNS \(context): \(error.localizedDescription)")
        }
    }

    private func resolvedTunDNSServer() async -> String {
        guard
            let configPath = await resolveSelectedConfigPath(),
            let raw = try? String(contentsOfFile: configPath, encoding: .utf8)
        else {
            return Self.defaultTunDNSServer
        }

        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        if let hijackServer = self.tunDNSHijackServer(from: lines) {
            return hijackServer
        }

        if let fakeIPServer = self.fakeIPRangeHost(from: lines) {
            return fakeIPServer
        }

        return Self.defaultTunDNSServer
    }

    func ensureTunMixedStackOnStartupIfNeeded() async {
        guard self.isRuntimeRunning else { return }

        do {
            let config = try await fetchRuntimeConfigSnapshot()
            guard config.tunEnabled == true else { return }
            let hasConfiguredStack = await self.selectedConfigDeclaresTunStack()

            let client = try clientOrThrow()
            var body: [String: JSONValue] = [
                "dns": .object(["enable": .bool(true)]),
            ]
            if !hasConfiguredStack {
                body["tun"] = .object(["stack": .string("mixed")])
            }
            try await self.makePatchRuntimeConfigUseCase(using: client).execute(body: body)
        } catch {
            appendLog(level: "error", message: tr("log.tun.startup_check_failed", self.tunErrorMessage(error)))
        }
    }

    func selectedConfigDeclaresTunStack() async -> Bool {
        guard
            let configPath = await resolveSelectedConfigPath(),
            let raw = try? String(contentsOfFile: configPath, encoding: .utf8)
        else {
            return false
        }

        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let tunRange = self.topLevelBlockRange(for: "tun", lines: lines) else { return false }
        return self.childLineExists(for: "stack", lines: lines, range: tunRange)
    }

    private func childLineExists(for key: String, lines: [String], range: Range<Int>) -> Bool {
        for index in (range.lowerBound + 1)..<range.upperBound {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let leadingSpaces = leadingWhitespaceCount(in: line)
            guard leadingSpaces > 0 else { continue }

            let content = String(line.dropFirst(leadingSpaces)).trimmingCharacters(in: .whitespaces)
            if content == "\(key):" || content.hasPrefix("\(key): ") {
                return true
            }
        }
        return false
    }

    private func childScalarValue(for key: String, lines: [String], range: Range<Int>) -> String? {
        for index in (range.lowerBound + 1)..<range.upperBound {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let leadingSpaces = leadingWhitespaceCount(in: line)
            guard leadingSpaces > 0 else { continue }

            let content = String(line.dropFirst(leadingSpaces)).trimmingCharacters(in: .whitespaces)
            if content == "\(key):" {
                return nil
            }

            guard content.hasPrefix("\(key):") else { continue }
            let valueStart = content.index(content.startIndex, offsetBy: key.count + 1)
            let value = stripYAMLInlineComment(String(content[valueStart...]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedYAMLScalar(value)
        }
        return nil
    }

    private func tunDNSHijackServer(from lines: [String]) -> String? {
        guard let tunRange = self.topLevelBlockRange(for: "tun", lines: lines) else { return nil }
        guard let hijackRange = self.childBlockRange(for: "dns-hijack", lines: lines, parentRange: tunRange) else {
            return nil
        }

        for index in hijackRange {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("-") else { continue }

            let item = stripYAMLInlineComment(String(trimmed.dropFirst()))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let host = self.extractHost(fromAddressLike: item) {
                return host
            }
        }

        if let inlineValue = self.childScalarValue(for: "dns-hijack", lines: lines, range: tunRange) {
            return self.extractHost(fromAddressLike: inlineValue)
        }

        return nil
    }

    private func fakeIPRangeHost(from lines: [String]) -> String? {
        guard let dnsRange = self.topLevelBlockRange(for: "dns", lines: lines) else { return nil }
        guard let fakeIPRange = self.childScalarValue(for: "fake-ip-range", lines: lines, range: dnsRange) else {
            return nil
        }
        return self.extractHost(fromCIDR: fakeIPRange)
    }

    private func childBlockRange(for key: String, lines: [String], parentRange: Range<Int>) -> Range<Int>? {
        var start: Int?
        var childIndent: Int?

        for index in (parentRange.lowerBound + 1)..<parentRange.upperBound {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let indent = leadingWhitespaceCount(in: line)
            guard indent > 0 else { continue }

            let content = String(line.dropFirst(indent)).trimmingCharacters(in: .whitespaces)
            if start == nil {
                guard content == "\(key):" else { continue }
                start = index + 1
                childIndent = indent
                continue
            }

            guard let start, let childIndent else { break }
            if indent <= childIndent {
                return start..<index
            }
        }

        if let start {
            return start..<parentRange.upperBound
        }
        return nil
    }

    private func extractHost(fromCIDR value: String) -> String? {
        let host = value.split(separator: "/", maxSplits: 1).first.map(String.init) ?? value
        return self.normalizedIPv4Address(host)
    }

    private func extractHost(fromAddressLike value: String) -> String? {
        if let ipv4 = self.normalizedIPv4Address(value) {
            return ipv4
        }

        if let colonIndex = value.firstIndex(of: ":") {
            let host = String(value[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            return self.normalizedIPv4Address(host)
        }

        return nil
    }

    private func normalizedIPv4Address(_ value: String) -> String? {
        let trimmed = normalizedYAMLScalar(value) ?? ""
        let pattern = #"^(?:\d{1,3}\.){3}\d{1,3}$"#
        guard trimmed.range(of: pattern, options: [.regularExpression]) != nil else { return nil }
        let parts = trimmed.split(separator: ".")
        guard parts.count == 4 else { return nil }
        for part in parts {
            guard let octet = Int(part), (0...255).contains(octet) else { return nil }
        }
        return trimmed
    }

    private func topLevelBlockRange(for key: String, lines: [String]) -> Range<Int>? {
        guard let start = lines.firstIndex(where: { self.isTopLevelKeyLine($0, key: key) }) else {
            return nil
        }

        var end = lines.count
        if start + 1 < lines.count {
            for index in (start + 1)..<lines.count where self.isTopLevelMappingLine(lines[index]) {
                end = index
                break
            }
        }
        return start..<end
    }

    private func isTopLevelKeyLine(_ line: String, key: String) -> Bool {
        guard line.prefix(while: { $0 == " " || $0 == "\t" }).isEmpty else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        return trimmed == "\(key):" || trimmed.hasPrefix("\(key): ")
    }

    private func isTopLevelMappingLine(_ line: String) -> Bool {
        guard line.prefix(while: { $0 == " " || $0 == "\t" }).isEmpty else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        return trimmed.contains(":")
    }

    func refreshTunStatusFromRuntimeConfig() async {
        do {
            let config = try await fetchRuntimeConfigSnapshot()
            if let tunEnabled = config.tunEnabled, isTunEnabled != tunEnabled {
                isTunEnabled = tunEnabled
                persistEditableSettingsSnapshot()
            }
        } catch {
            // Keep current UI state when runtime config refresh is unavailable.
        }
    }
}
