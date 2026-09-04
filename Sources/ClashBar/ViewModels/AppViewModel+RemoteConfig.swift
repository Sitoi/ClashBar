import AppKit
import Foundation
import UniformTypeIdentifiers

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

@MainActor
extension AppViewModel {
    func importRemoteConfigFile() async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        guard let input = promptRemoteConfigImportInput() else { return }

        let urlText = input.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = URL(string: urlText), isSupportedRemoteConfigURL(remoteURL) else {
            let message = tr("log.config.remote.invalid_url", urlText)
            appendLog(level: "error", message: message)
            self.presentRemoteConfigImportResultAlert(success: false, message: message)
            return
        }

        let fallbackName = self.inferredRemoteConfigFileName(from: remoteURL)
        guard let fileName = normalizedConfigFileName(input.fileName, fallback: fallbackName) else {
            let message = tr("log.config.import.invalid_filename", input.fileName)
            appendLog(level: "error", message: message)
            self.presentRemoteConfigImportResultAlert(success: false, message: message)
            return
        }

        let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
        let existsAlready = FileManager.default.fileExists(atPath: targetURL.path)
        let existingIsRemote = self.remoteConfigSubscriptions[fileName] != nil

        if existsAlready, !existingIsRemote {
            guard self.confirmOverwriteConfig(named: fileName) else {
                appendLog(level: "info", message: tr("log.config.import.cancelled", fileName))
                return
            }
        }

        do {
            let userAgent = await remoteSubscriptionUserAgent()
            let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
            let change = try await self.writeRemoteConfigDataIfChanged(data, to: targetURL)

            let subscription = RemoteConfigSubscription(
                urlString: remoteURL.absoluteString,
                autoUpdateEnabled: input.autoUpdateEnabled,
                autoUpdateIntervalHours: input.autoUpdateIntervalHours,
                lastUpdateCheckAt: Date())
            self.upsertRemoteConfigSubscription(for: fileName, subscription: subscription)
            let message = tr("log.config.import_remote.success", fileName)
            appendLog(level: "info", message: message)

            await self.applyRemoteConfigChange(change, fileName: fileName)
            self.presentRemoteConfigImportResultAlert(success: true, message: message)
        } catch {
            let message = tr("log.config.import_remote.failed", fileName, error.localizedDescription)
            appendLog(level: "error", message: message)
            self.presentRemoteConfigImportResultAlert(success: false, message: message)
        }
    }

    func updateAllRemoteConfigFiles() async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        pruneRemoteConfigSubscriptionsIfNeeded()

        let subscriptions = remoteConfigSubscriptions
        guard !subscriptions.isEmpty else {
            appendLog(level: "info", message: tr("log.config.remote.no_sources"))
            return
        }

        let userAgent = await remoteSubscriptionUserAgent()
        var succeededCount = 0
        var failedCount = 0
        var changedConfigs: [String: RemoteConfigFileChange] = [:]

        for fileName in subscriptions.keys.sorted() {
            guard let sub = subscriptions[fileName],
                  let remoteURL = URL(string: sub.urlString),
                  isSupportedRemoteConfigURL(remoteURL)
            else {
                failedCount += 1
                appendLog(
                    level: "error",
                    message: tr(
                        "log.config.remote.update_item_failed",
                        fileName,
                        tr("log.config.remote.invalid_url", subscriptions[fileName]?.urlString ?? fileName)))
                continue
            }

            let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
            let checkAt = Date()
            do {
                let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
                guard let refreshedSubscription = self.checkedRemoteConfigSubscription(
                    for: fileName,
                    baseline: sub,
                    at: checkAt)
                else {
                    continue
                }
                let change = try await self.writeRemoteConfigDataIfChanged(data, to: targetURL)
                self.remoteConfigSubscriptions[fileName] = refreshedSubscription
                succeededCount += 1
                if change.contentsChanged {
                    changedConfigs[fileName] = change
                }
            } catch {
                guard let refreshedSubscription = self.checkedRemoteConfigSubscription(
                    for: fileName,
                    baseline: sub,
                    at: checkAt)
                else {
                    continue
                }
                self.remoteConfigSubscriptions[fileName] = refreshedSubscription
                failedCount += 1
                appendLog(
                    level: "error",
                    message: tr("log.config.remote.update_item_failed", fileName, error.localizedDescription))
            }
        }

        self.persistRemoteConfigSubscriptions()
        self.refreshRemoteConfigMenuStates()
        appendLog(level: "info", message: tr("log.config.remote.update_summary", succeededCount, failedCount))

        let selectedFileName = self.selectedConfigName
        if let selectedConfigChange = changedConfigs[selectedFileName] {
            await self.applyRemoteConfigChange(selectedConfigChange, fileName: selectedFileName)
        }
    }

    func deleteConfigFile(named fileName: String) async {
        guard self.confirmDeleteConfig(named: fileName) else { return }
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }

        let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
        let isDeletingSelected = fileName == selectedConfigName
        let isCurrentlyRunning = isRuntimeRunning

        do {
            try FileManager.default.removeItem(at: targetURL)
        } catch {
            appendLog(level: "error", message: tr("log.config.delete.failed", fileName, error.localizedDescription))
            return
        }

        self.removeRemoteConfigSubscription(for: fileName)
        _ = configRepository.reloadConfigs()
        syncConfigDisplayState()

        appendLog(level: "info", message: tr("log.config.delete.success", fileName))

        guard isDeletingSelected else { return }

        if let nextConfig = configRepository.availableConfigs.first {
            configRepository.selectConfig(nextConfig)
            let nextName = nextConfig.lastPathComponent
            selectedConfigName = nextName
            defaults.set(nextName, forKey: selectedConfigKey)
            appendLog(level: "info", message: tr("log.config.selected", nextName))
            if isCurrentlyRunning {
                await restartCoreIfNeededForConfigSwitch(
                    previousPath: targetURL.path,
                    nextPath: nextConfig.path)
            }
        } else {
            selectedConfigName = "-"
            defaults.removeObject(forKey: selectedConfigKey)
            if isCurrentlyRunning {
                await stopCore(trigger: .manual)
            }
        }
    }

    private func confirmDeleteConfig(named fileName: String) -> Bool {
        self.runModalAlert(
            style: .warning,
            message: tr("app.config.delete.title", fileName),
            informative: tr("app.config.delete.message"),
            buttons: [tr("ui.action.delete"), tr("ui.action.cancel")]) == .alertFirstButtonReturn
    }

    func showSelectedConfigInFinder() {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        if let selected = configRepository.selectedConfig, FileManager.default.fileExists(atPath: selected.path) {
            NSWorkspace.shared.activateFileViewerSelecting([selected])
            return
        }

        if !NSWorkspace.shared.open(configDirectory) {
            appendLog(level: "error", message: tr("log.config.show_in_finder.failed", configDirectory.path))
        }
    }

    func showCoreDirectoryInFinder() {
        do {
            try workingDirectoryManager.bootstrapDirectories()
            let coreDirectory = try workingDirectoryManager.normalizeAndValidateWithinRoot(
                workingDirectoryManager.coreDirectoryURL,
                mustBeDirectory: true)
            if !NSWorkspace.shared.open(coreDirectory) {
                appendLog(level: "error", message: tr("log.core.show_in_finder.failed", coreDirectory.path))
            }
        } catch {
            appendLog(
                level: "error",
                message: tr("log.core.show_in_finder.failed", workingDirectoryManager.coreDirectoryURL.path))
        }
    }

    func reloadConfigFileList() {
        guard self.ensureConfigDirectoryAvailable() != nil else { return }
        self.refreshConfigStateAfterMutation()
        appendLog(level: "info", message: tr("log.config.loaded_count", configRepository.availableConfigs.count))
    }

    func refreshRemoteConfigMenuStates() {
        let subscriptions = self.remoteConfigSubscriptions
        guard !subscriptions.isEmpty else {
            self.remoteConfigMenuStates = [:]
            return
        }

        var nextStates: [String: RemoteConfigMenuState] = [:]
        nextStates.reserveCapacity(subscriptions.count)

        for (fileName, sub) in subscriptions {
            let updatedAt = self.remoteConfigUpdatedAt(for: fileName)
            nextStates[fileName] = self.mergedRemoteConfigMenuState(
                for: fileName,
                updatedAt: updatedAt,
                subscription: sub)
        }

        self.remoteConfigMenuStates = nextStates
    }

    func remoteConfigMenuState(for fileName: String) -> RemoteConfigMenuState {
        self.remoteConfigMenuStates[fileName] ?? .idle
    }

    func refreshRemoteConfigFile(named fileName: String) async {
        guard self.remoteConfigMenuState(for: fileName).phase != .refreshing else { return }
        guard let configDirectory = self.ensureConfigDirectoryAvailable() else { return }

        self.pruneRemoteConfigSubscriptionsIfNeeded()
        self.setRemoteConfigMenuState(for: fileName, phase: .refreshing)
        defer {
            if self.remoteConfigMenuState(for: fileName).phase == .refreshing {
                self.setRemoteConfigMenuState(for: fileName, phase: .idle)
            }
        }

        guard let sub = self.remoteConfigSubscriptions[fileName],
              let remoteURL = URL(string: sub.urlString),
              isSupportedRemoteConfigURL(remoteURL)
        else {
            let stored = self.remoteConfigSubscriptions[fileName]?.urlString ?? fileName
            let reason = tr("log.config.remote.invalid_url", stored)
            self.appendLog(level: "error", message: tr("log.config.remote.update_item_failed", fileName, reason))
            self.setRemoteConfigMenuState(for: fileName, phase: .failed)
            return
        }

        let checkAt = Date()
        do {
            let userAgent = await self.remoteSubscriptionUserAgent()
            let data = try await self.downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
            guard let refreshedSubscription = self.checkedRemoteConfigSubscription(
                for: fileName,
                baseline: sub,
                at: checkAt)
            else {
                return
            }
            let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
            let change = try await self.writeRemoteConfigDataIfChanged(data, to: targetURL)

            self.remoteConfigSubscriptions[fileName] = refreshedSubscription
            self.persistRemoteConfigSubscriptions()
            await self.applyRemoteConfigChange(change, fileName: fileName)

            self.setRemoteConfigMenuState(
                for: fileName,
                phase: .idle,
                updatedAt: self.remoteConfigUpdatedAt(for: fileName) ?? Date())
        } catch {
            guard let refreshedSubscription = self.checkedRemoteConfigSubscription(
                for: fileName,
                baseline: sub,
                at: checkAt)
            else {
                return
            }
            self.remoteConfigSubscriptions[fileName] = refreshedSubscription
            self.persistRemoteConfigSubscriptions()
            self.appendLog(
                level: "error",
                message: tr("log.config.remote.update_item_failed", fileName, error.localizedDescription))
            self.setRemoteConfigMenuState(for: fileName, phase: .failed)
        }
    }

    func reloadConfig() async {
        let actionName = tr("log.action_name.reload_config")
        let expectedTunEnabled = isTunEnabled

        do {
            ensureAPIClient()
            try await self.clientOrThrow().requestNoResponse(.putConfigs(force: false))
            try await self.restoreTunAfterConfigReloadIfNeeded(expectedEnabled: expectedTunEnabled)
            appendLog(level: "info", message: tr("log.action.success", actionName))
        } catch {
            appendLog(level: "error", message: tr("log.action.failed", actionName, error.localizedDescription))
        }
    }

    func ensureConfigDirectoryAvailable() -> URL? {
        if let configDirectory = configRepository.configDirectory {
            return configDirectory
        }

        do {
            try workingDirectoryManager.bootstrapDirectories()
            configRepository.setConfigDirectory(workingDirectoryManager.configDirectoryURL)
            self.refreshConfigStateAfterMutation()
            return configRepository.configDirectory
        } catch {
            appendLog(level: "error", message: tr("log.working_dir_init_failed", error.localizedDescription))
            return nil
        }
    }

    private func refreshConfigStateAfterMutation() {
        _ = configRepository.reloadConfigs()
        if self.syncSelectedConfigSelection(configRepository.selectedConfig) == nil {
            selectedConfigName = "-"
            defaults.removeObject(forKey: selectedConfigKey)
        }
        syncConfigDisplayState()
    }

    @discardableResult
    func syncSelectedConfigSelection(_ selected: URL?) -> String? {
        self.configDirectoryMonitor?.updateSelectedFile(selected)
        guard let selected else { return nil }
        selectedConfigName = selected.lastPathComponent
        defaults.set(selected.lastPathComponent, forKey: selectedConfigKey)
        return selected.path
    }

    func shouldAutoReloadCurrentConfig(updatedFileNames: Set<String>) -> Bool {
        guard !updatedFileNames.isEmpty else { return false }
        guard isRuntimeRunning else { return false }
        guard !isRemoteTarget else { return false }
        return updatedFileNames.contains(selectedConfigName)
    }

    func writeConfigData(_ data: Data, to targetURL: URL) throws {
        try configRepository.writeConfigData(data, to: targetURL)
    }

    private struct RemoteConfigFileChange: Sendable {
        let contentsChanged: Bool
        let requiresFullRestart: Bool

        static let unchanged = RemoteConfigFileChange(contentsChanged: false, requiresFullRestart: false)
    }

    /// Compares downloaded bytes before validation and atomic replacement. For a
    /// changed file, update the monitor snapshot synchronously so this app-owned
    /// write is applied exactly once by `applyRemoteConfigChange` below.
    private func writeRemoteConfigDataIfChanged(
        _ data: Data,
        to targetURL: URL) async throws -> RemoteConfigFileChange
    {
        let change = try await Task.detached(priority: .utility) {
            let existingData: Data?
            if FileManager.default.fileExists(atPath: targetURL.path) {
                existingData = try Data(contentsOf: targetURL)
            } else {
                existingData = nil
            }

            guard existingData != data else {
                return RemoteConfigFileChange.unchanged
            }
            return RemoteConfigFileChange(
                contentsChanged: true,
                requiresFullRestart: Self.remoteConfigRequiresFullRestart(
                    previous: existingData,
                    updated: data))
        }.value
        guard change.contentsChanged else {
            return .unchanged
        }

        try await self.validateRemoteConfigData(data, targetURL: targetURL)
        try self.writeConfigData(data, to: targetURL)
        self.synchronizeConfigDirectoryMonitorSnapshot(for: targetURL)
        return change
    }

    /// Validates the candidate beside the destination so Mihomo resolves relative
    /// provider paths against the same working directory. Hidden files are ignored
    /// by the config directory scanner and are always removed after validation.
    private func validateRemoteConfigData(_ data: Data, targetURL: URL) async throws {
        let candidateURL = targetURL.deletingLastPathComponent().appendingPathComponent(
            ".clashbar-validation-\(UUID().uuidString).\(targetURL.pathExtension)",
            isDirectory: false)
        try await Task.detached(priority: .utility) {
            try data.write(to: candidateURL, options: .atomic)
        }.value
        defer { try? FileManager.default.removeItem(at: candidateURL) }

        guard let details = await self.configValidationFailureDetails(configPath: candidateURL.path) else {
            return
        }
        throw NSError(
            domain: "ClashBar.RemoteConfigValidation",
            code: 422,
            userInfo: [
                NSLocalizedDescriptionKey: self.tr(
                    "log.config.validate_failed",
                    targetURL.lastPathComponent,
                    details),
            ])
    }

    private func applyRemoteConfigChange(_ change: RemoteConfigFileChange, fileName: String) async {
        guard change.contentsChanged else { return }
        guard self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) else { return }

        while self.isCoreActionProcessing {
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
        }
        guard self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) else { return }
        guard let selectedConfig = self.configRepository.selectedConfig,
              selectedConfig.lastPathComponent == fileName
        else { return }

        if change.requiresFullRestart {
            guard self.selectedConfigName == fileName else { return }
            self.appendLog(level: "info", message: self.tr("log.config.remote.restart_required"))
            // restartCore validates the new file before stopping the running core.
            await self.restartCore(trigger: .configSwitch)
            return
        }

        guard self.selectedConfigName == fileName else { return }

        let actionName = self.tr("log.action_name.reload_config")
        let expectedTunEnabled = self.isTunEnabled
        do {
            self.ensureAPIClient()
            try await self.clientOrThrow().requestNoResponse(.putConfigs(force: true))
            try await self.restoreTunAfterConfigReloadIfNeeded(expectedEnabled: expectedTunEnabled)
            self.appendLog(level: "info", message: self.tr("log.action.success", actionName))
        } catch {
            self.appendLog(
                level: "warning",
                message: self.tr("log.config.remote.hot_reload_fallback_restart", error.localizedDescription))
            await self.restartCore(trigger: .configSwitch)
        }
    }

    /// Mihomo's config API updates runtime components, but it does not recreate
    /// the external-controller server. A change to one of these top-level route
    /// sections must therefore be applied by starting a new core process.
    private nonisolated static func remoteConfigRequiresFullRestart(
        previous: Data?,
        updated: Data) -> Bool
    {
        guard let previous,
              let previousSections = self.mihomoStartupSectionFingerprint(in: previous),
              let updatedSections = self.mihomoStartupSectionFingerprint(in: updated)
        else {
            return true
        }
        return previousSections != updatedSections
    }

    private nonisolated static func mihomoStartupSectionFingerprint(in data: Data) -> [String: String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let keys: Set<String> = [
            "external-controller",
            "external-controller-cors",
            "external-controller-pipe",
            "external-controller-routing-mark",
            "external-controller-tls",
            "external-controller-unix",
            "external-doh-server",
            "external-ui",
            "external-ui-name",
            "external-ui-url",
            "secret",
            "tls",
        ]
        var sections: [String: String] = [:]
        var activeKey: String?
        var activeLines: [String] = []

        func commitSection() {
            guard let activeKey else { return }
            sections[activeKey] = activeLines.joined(separator: "\n")
        }

        for rawLine in text.components(separatedBy: .newlines) {
            guard let line = self.normalizedYAMLLine(rawLine) else { continue }
            if let first = line.first, !first.isWhitespace,
               let colon = line.firstIndex(of: ":")
            {
                commitSection()
                let rawKey = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                activeKey = keys.contains(key) ? key : nil
                activeLines = activeKey == nil ? [] : [line]
            } else if activeKey != nil {
                activeLines.append(line)
            }
        }
        commitSection()
        return sections
    }

    /// Removes YAML comments without treating a `#` inside a quoted or plain
    /// non-whitespace-delimited scalar as a comment. Leading indentation remains
    /// intact because it is semantically significant in YAML.
    private nonisolated static func normalizedYAMLLine(_ line: String) -> String? {
        let characters = Array(line)
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var isEscapingDoubleQuote = false
        var commentStart: Int?

        for index in characters.indices {
            let character = characters[index]
            if inDoubleQuotes, character == "\\", !isEscapingDoubleQuote {
                isEscapingDoubleQuote = true
                continue
            }
            if character == "\"", !inSingleQuotes, !isEscapingDoubleQuote {
                inDoubleQuotes.toggle()
            } else if character == "'", !inDoubleQuotes {
                inSingleQuotes.toggle()
            } else if character == "#", !inSingleQuotes, !inDoubleQuotes,
                      index == characters.startIndex || characters[characters.index(before: index)].isWhitespace
            {
                commentStart = index
                break
            }
            isEscapingDoubleQuote = false
        }

        let content = String(characters[..<(commentStart ?? characters.endIndex)])
        let normalized = self.trimmingTrailingWhitespace(content)
        return normalized.trimmingCharacters(in: .whitespaces).isEmpty ? nil : normalized
    }

    private nonisolated static func trimmingTrailingWhitespace(_ value: String) -> String {
        var endIndex = value.endIndex
        while endIndex > value.startIndex {
            let previousIndex = value.index(before: endIndex)
            guard value[previousIndex].isWhitespace else { break }
            endIndex = previousIndex
        }
        return String(value[..<endIndex])
    }

    func confirmOverwriteConfig(named fileName: String) -> Bool {
        self.runModalAlert(
            style: .warning,
            message: tr("app.config.import.overwrite.title", fileName),
            informative: tr("app.config.import.overwrite.message"),
            buttons: [tr("ui.action.overwrite"), tr("ui.action.cancel")]) == .alertFirstButtonReturn
    }

    private func presentRemoteConfigImportResultAlert(success: Bool, message: String) {
        self.runModalAlert(
            style: success ? .informational : .warning,
            message: success
                ? tr("app.config.remote_import.alert.success.title")
                : tr("app.config.remote_import.alert.failure.title"),
            informative: message,
            buttons: [tr("ui.action.ok")])
    }

    private struct RemoteConfigImportInput {
        let urlString: String
        let fileName: String
        let autoUpdateEnabled: Bool
        let autoUpdateIntervalHours: Int
    }

    private func promptRemoteConfigImportInput() -> RemoteConfigImportInput? {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 142))

        let urlLabel = NSTextField(labelWithString: tr("ui.quick.remote.url_label"))
        urlLabel.font = .systemFont(ofSize: T.FontSize.callout, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 124, width: 340, height: 16)

        let urlField = NSTextField(frame: NSRect(x: 0, y: 98, width: 340, height: 24))
        urlField.placeholderString = tr("ui.quick.remote.url_placeholder")

        let fileLabel = NSTextField(labelWithString: tr("ui.quick.remote.filename_label"))
        fileLabel.font = .systemFont(ofSize: T.FontSize.callout, weight: .medium)
        fileLabel.frame = NSRect(x: 0, y: 76, width: 340, height: 16)

        let fileField = NSTextField(frame: NSRect(x: 0, y: 50, width: 340, height: 24))
        fileField.placeholderString = tr("ui.quick.remote.filename_placeholder")

        let separator = NSBox(frame: NSRect(x: 0, y: 38, width: 340, height: 1))
        separator.boxType = .separator

        let autoUpdateCheckbox = NSButton(
            checkboxWithTitle: tr("ui.quick.remote.auto_update_label"),
            target: nil,
            action: nil)
        autoUpdateCheckbox.frame = NSRect(x: 0, y: 8, width: 140, height: 22)
        autoUpdateCheckbox.state = .on

        let intervalUnit = NSTextField(labelWithString: tr("ui.quick.remote.interval_unit"))
        intervalUnit.font = .systemFont(ofSize: T.FontSize.callout, weight: .regular)
        intervalUnit.textColor = .secondaryLabelColor
        intervalUnit.frame = NSRect(x: 306, y: 12, width: 34, height: 16)

        let intervalField = NSTextField(frame: NSRect(x: 252, y: 8, width: 50, height: 22))
        intervalField.stringValue = "\(RemoteConfigSubscription.defaultAutoUpdateIntervalHours)"
        intervalField.alignment = .center

        let eachLabel = NSTextField(labelWithString: tr("ui.quick.remote.interval_each"))
        eachLabel.font = .systemFont(ofSize: T.FontSize.callout, weight: .regular)
        eachLabel.textColor = .secondaryLabelColor
        eachLabel.frame = NSRect(x: 220, y: 12, width: 28, height: 16)

        container.addSubview(urlLabel)
        container.addSubview(urlField)
        container.addSubview(fileLabel)
        container.addSubview(fileField)
        container.addSubview(separator)
        container.addSubview(autoUpdateCheckbox)
        container.addSubview(eachLabel)
        container.addSubview(intervalField)
        container.addSubview(intervalUnit)

        let response = self.runModalAlert(
            style: .informational,
            message: tr("ui.quick.import_remote_config"),
            informative: tr("app.config.remote_import.prompt"),
            buttons: [tr("ui.action.import"), tr("ui.action.cancel")]) { $0.accessoryView = container }
        guard response == .alertFirstButtonReturn else { return nil }

        let autoUpdate = autoUpdateCheckbox.state == .on
        let intervalHours = max(
            RemoteConfigSubscription.minimumAutoUpdateIntervalHours,
            Int(intervalField.stringValue) ?? RemoteConfigSubscription.defaultAutoUpdateIntervalHours)

        return RemoteConfigImportInput(
            urlString: urlField.stringValue,
            fileName: fileField.stringValue,
            autoUpdateEnabled: autoUpdate,
            autoUpdateIntervalHours: intervalHours)
    }

    func normalizedConfigFileName(_ fileName: String, fallback: String? = nil) -> String? {
        configRepository.normalizedConfigFileName(fileName, fallback: fallback)
    }

    private func inferredRemoteConfigFileName(from remoteURL: URL) -> String {
        configRepository.inferredRemoteConfigFileName(from: remoteURL)
    }

    func isSupportedRemoteConfigURL(_ url: URL) -> Bool {
        configRepository.isSupportedRemoteConfigURL(url)
    }

    private func downloadRemoteConfigData(from remoteURL: URL, userAgent: String? = nil) async throws -> Data {
        try await configRepository.downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
    }

    private static let defaultMihomoVersionForUserAgent = "v1.19.27"

    private func remoteSubscriptionUserAgent() async -> String {
        let version = await resolvedMihomoVersionForSubscriptionUserAgent()
        return "clash.meta/\(version)"
    }

    private func resolvedMihomoVersionForSubscriptionUserAgent() async -> String {
        if let current = normalizedMihomoVersionForUserAgent(self.version) {
            return current
        }

        guard let client = try? clientOrThrow() else {
            return Self.defaultMihomoVersionForUserAgent
        }

        guard let fetched: VersionInfo = try? await client.request(.version) else {
            return Self.defaultMihomoVersionForUserAgent
        }

        let normalized = self.normalizedMihomoVersionForUserAgent(fetched.version) ?? Self
            .defaultMihomoVersionForUserAgent
        if normalized != Self.defaultMihomoVersionForUserAgent {
            self.version = normalized
        }
        return normalized
    }

    private func normalizedMihomoVersionForUserAgent(_ rawVersion: String) -> String? {
        let trimmed = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "-" else { return nil }
        return trimmed
    }

    private func restoreTunAfterConfigReloadIfNeeded(expectedEnabled: Bool) async throws {
        guard isRuntimeRunning else { return }
        try await self.patchTunConfig(enable: expectedEnabled)
        try await self.verifyTunRuntimeState(expectedEnabled: expectedEnabled)
        if isTunEnabled != expectedEnabled {
            isTunEnabled = expectedEnabled
            persistEditableSettingsSnapshot()
        }
    }

    private func upsertRemoteConfigSubscription(for fileName: String, subscription: RemoteConfigSubscription) {
        remoteConfigSubscriptions[fileName] = subscription
        persistRemoteConfigSubscriptions()
        self.restartRemoteConfigBackgroundTasksIfNeeded()
        self.refreshConfigStateAfterMutation()
    }

    func removeRemoteConfigSubscription(for fileName: String) {
        guard remoteConfigSubscriptions[fileName] != nil else { return }
        remoteConfigSubscriptions.removeValue(forKey: fileName)
        persistRemoteConfigSubscriptions()
        self.restartRemoteConfigBackgroundTasksIfNeeded()
        self.refreshConfigStateAfterMutation()
    }

    private func checkedRemoteConfigSubscription(
        for fileName: String,
        baseline: RemoteConfigSubscription,
        at checkAt: Date) -> RemoteConfigSubscription?
    {
        guard self.remoteConfigSubscriptions[fileName] == baseline else { return nil }
        return baseline.markChecked(at: checkAt)
    }

    private func remoteConfigUpdatedAt(for fileName: String) -> Date? {
        guard let configURL = self.configRepository.availableConfigs.first(where: { $0.lastPathComponent == fileName })
        else {
            return nil
        }
        return try? configURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func mergedRemoteConfigMenuState(
        for fileName: String,
        updatedAt: Date?,
        subscription: RemoteConfigSubscription) -> RemoteConfigMenuState
    {
        let current = self.remoteConfigMenuStates[fileName] ?? .idle
        let phase: RemoteConfigRefreshPhase = switch current.phase {
        case .refreshing:
            .refreshing
        case .failed:
            current.updatedAt == updatedAt ? .failed : .idle
        case .idle:
            .idle
        }
        return RemoteConfigMenuState(
            updatedAt: updatedAt,
            phase: phase,
            autoUpdateEnabled: subscription.autoUpdateEnabled,
            nextUpdateAt: subscription.nextUpdateAt())
    }

    private func setRemoteConfigMenuState(
        for fileName: String,
        phase: RemoteConfigRefreshPhase,
        updatedAt: Date? = nil)
    {
        let existing = self.remoteConfigMenuStates[fileName]
        let sub = self.remoteConfigSubscriptions[fileName]
        let resolvedUpdatedAt = updatedAt ?? existing?.updatedAt
        self.remoteConfigMenuStates[fileName] = RemoteConfigMenuState(
            updatedAt: resolvedUpdatedAt,
            phase: phase,
            autoUpdateEnabled: sub?.autoUpdateEnabled ?? false,
            nextUpdateAt: sub?.nextUpdateAt())
    }

    func startRemoteConfigAutoUpdateTaskIfNeeded() {
        guard remoteConfigAutoUpdateTask == nil || remoteConfigAutoUpdateTask?.isCancelled == true else { return }
        let hasAutoUpdate = remoteConfigSubscriptions.values.contains { $0.autoUpdateEnabled }
        guard hasAutoUpdate else { return }
        remoteConfigAutoUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performDueRemoteConfigAutoUpdatesIfNeeded()
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
            }
        }
    }

    func stopRemoteConfigAutoUpdateTask() {
        remoteConfigAutoUpdateTask?.cancel()
        remoteConfigAutoUpdateTask = nil
    }

    func restartRemoteConfigAutoUpdateTaskIfNeeded() {
        self.stopRemoteConfigAutoUpdateTask()
        self.startRemoteConfigAutoUpdateTaskIfNeeded()
    }

    func restartRemoteConfigBackgroundTasksIfNeeded() {
        self.restartRemoteConfigAutoUpdateTaskIfNeeded()
        self.stopRemoteConfigMenuRefreshTimer()
        self.startRemoteConfigMenuRefreshTimerIfNeeded()
    }

    func performDueRemoteConfigAutoUpdatesIfNeeded() async {
        let due = remoteConfigSubscriptions
            .compactMap { $0.value.isDue() ? $0.key : nil }
            .sorted()
        guard !due.isEmpty else { return }
        for fileName in due {
            guard !Task.isCancelled else { break }
            await self.refreshRemoteConfigFile(named: fileName)
        }
    }

    func startRemoteConfigMenuRefreshTimerIfNeeded() {
        guard remoteConfigMenuRefreshTask == nil || remoteConfigMenuRefreshTask?.isCancelled == true else { return }
        guard !remoteConfigSubscriptions.isEmpty else { return }
        remoteConfigMenuRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
                self?.refreshRemoteConfigMenuStates()
            }
        }
    }

    func stopRemoteConfigMenuRefreshTimer() {
        remoteConfigMenuRefreshTask?.cancel()
        remoteConfigMenuRefreshTask = nil
    }
}
