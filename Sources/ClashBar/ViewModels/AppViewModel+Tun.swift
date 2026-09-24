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
extension AppViewModel {
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
            try await self.patchTunConfig(enable: enabled)

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

    static let mipsStackMinimumCoreVersion = "1.19.31"

    var isMipsStackSupported: Bool {
        guard let current = AppSemanticVersion(self.version),
              let minimum = AppSemanticVersion(Self.mipsStackMinimumCoreVersion)
        else {
            return false
        }
        return current >= minimum
    }

    func selectTunStack(_ stack: String) async {
        guard !isTunSyncing else { return }

        if stack.caseInsensitiveCompare("mips") == .orderedSame, !self.isMipsStackSupported {
            let detail = tr("app.tun.mips_requires_upgrade", Self.mipsStackMinimumCoreVersion)
            self.statusItemBanner = StatusItemBanner(
                symbolName: "exclamationmark.triangle.fill",
                title: tr("ui.quick.tun_mode"),
                primaryDetail: detail,
                secondaryDetail: nil)
            appendLog(level: "warning", message: detail)
            return
        }

        if isTunEnabled, tunStack?.caseInsensitiveCompare(stack) == .orderedSame {
            return
        }

        isTunSyncing = true
        defer { isTunSyncing = false }

        do {
            if !self.isRemoteTarget {
                try await self.ensureTunPermissions(requestIfMissing: true)
            }
            guard self.isRemoteTarget || self.isRuntimeRunning else { return }

            try await self.patchTunConfig(enable: true, stack: stack)

            let config = try await fetchRuntimeConfigSnapshot()
            isTunEnabled = config.tunEnabled ?? false
            persistEditableSettingsSnapshot()

            if isTunEnabled {
                if !self.isRemoteTarget {
                    defaults.set(stack, forKey: tunStackKey)
                }
                appendLog(level: "info", message: tr("log.tun.stack_changed", stack))
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
        if let detected = processManager.detectedBinaryPath,
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
            try self.tunPermissionService.validateCurrentPermissions(binaryPath: binaryPath)
        } catch TunPermissionServiceError.permissionMissing {
            guard requestIfMissing else {
                throw TunPermissionServiceError.permissionMissing
            }
            appendLog(level: "info", message: tr("log.tun.permission_requesting"))
            try await self.tunPermissionService.grantPermissions(binaryPath: binaryPath)
            appendLog(level: "info", message: tr("log.tun.permission_granted"))
        }
    }

    func verifyTunAfterOverlayIfNeeded(overlay: EditableSettingsSnapshot) async {
        guard overlay.tunEnabled, isRuntimeRunning else { return }
        guard pendingCoreFeatureRecoveryState == nil else { return }

        do {
            let config = try await fetchRuntimeConfigSnapshot()
            if config.tunEnabled == true {
                isTunEnabled = true
                persistEditableSettingsSnapshot()
                return
            }

            try await self.patchTunConfig(enable: true)
            try await self.verifyTunRuntimeState(expectedEnabled: true)
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
        try await self.verifyTunRuntimeState(expectedEnabled: enabled)
    }

    func verifyTunRuntimeState(expectedEnabled: Bool) async throws {
        let config = try await fetchRuntimeConfigSnapshot()
        let actual = config.tunEnabled ?? false
        if actual != expectedEnabled {
            throw TunModeError.runtimeStateMismatch(expected: expectedEnabled)
        }
    }

    func patchTunConfig(enable: Bool, stack: String? = nil) async throws {
        let client = try clientOrThrow()
        var tunBody: [String: JSONValue] = ["enable": .bool(enable)]

        if let stack {
            tunBody["stack"] = .string(stack)
        } else if enable, let preferred = await self.preferredTunStack() {
            tunBody["stack"] = .string(preferred)
        }

        try await client.requestNoResponse(.patchConfigs(body: ["tun": .object(tunBody)]))
    }

    func preferredTunStack() async -> String? {
        if !self.isRemoteTarget, let saved = defaults.string(forKey: tunStackKey)?.trimmedNonEmpty {
            return saved
        }
        return await self.selectedConfigDeclaresTunStack() ? nil : "mixed"
    }

    func ensureTunStackOnStartupIfNeeded() async {
        guard self.isRuntimeRunning else { return }

        do {
            let config = try await fetchRuntimeConfigSnapshot()
            guard config.tunEnabled == true, let stack = await self.preferredTunStack() else { return }
            guard config.tun?.stack?.caseInsensitiveCompare(stack) != .orderedSame else { return }

            let client = try clientOrThrow()
            try await client.requestNoResponse(.patchConfigs(body: ["tun": .object(["stack": .string(stack)])]))
            _ = try await fetchRuntimeConfigSnapshot()
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
        guard let tunRange = Self.topLevelBlockRange(for: "tun", lines: lines) else { return false }
        return self.childLineExists(for: "stack", lines: lines, range: tunRange)
    }

    private func childLineExists(for key: String, lines: [String], range: Range<Int>) -> Bool {
        for index in (range.lowerBound + 1)..<range.upperBound {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let leadingSpaces = line.prefix { $0 == " " || $0 == "\t" }.count
            guard leadingSpaces > 0 else { continue }

            let content = String(line.dropFirst(leadingSpaces)).trimmingCharacters(in: .whitespaces)
            if content == "\(key):" || content.hasPrefix("\(key): ") {
                return true
            }
        }
        return false
    }

    static func topLevelBlockRange(for key: String, lines: [String]) -> Range<Int>? {
        guard let start = lines.firstIndex(where: { isTopLevelKeyLine($0, key: key) }) else {
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

    static func isTopLevelKeyLine(_ line: String, key: String) -> Bool {
        guard line.prefix(while: { $0 == " " || $0 == "\t" }).isEmpty else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        return trimmed == "\(key):" || trimmed.hasPrefix("\(key): ")
    }

    static func isTopLevelMappingLine(_ line: String) -> Bool {
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
        } catch {}
    }
}
