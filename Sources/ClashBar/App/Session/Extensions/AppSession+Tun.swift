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

    func patchTunConfig(enable: Bool) async throws {
        let client = try clientOrThrow()
        var tunBody: [String: JSONValue] = ["enable": .bool(enable)]

        if enable, await !self.selectedConfigDeclaresTunStack() {
            tunBody["stack"] = .string("mixed")
        }

        var body: [String: JSONValue] = ["tun": .object(tunBody)]
        if enable {
            body["dns"] = .object(["enable": .bool(true)])
        }
        try await self.makePatchRuntimeConfigUseCase(using: client).execute(body: body)
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
            if !hasConfiguredStack {
                _ = try await fetchRuntimeConfigSnapshot()
            }
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

            let leadingSpaces = line.prefix { $0 == " " || $0 == "\t" }.count
            guard leadingSpaces > 0 else { continue }

            let content = String(line.dropFirst(leadingSpaces)).trimmingCharacters(in: .whitespaces)
            if content == "\(key):" || content.hasPrefix("\(key): ") {
                return true
            }
        }
        return false
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
