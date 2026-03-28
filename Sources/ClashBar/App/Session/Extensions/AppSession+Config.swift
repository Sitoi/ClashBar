import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
extension AppSession {
    private enum RemoteConfigWriteResult {
        case changed
        case unchanged
    }

    private func reloadRuntimeConfigUseCase() throws -> ReloadRuntimeConfigUseCase {
        try ReloadRuntimeConfigUseCase(repository: DefaultRuntimeConfigRepository(transport: self.clientOrThrow()))
    }

    func isRemoteConfigFile(named fileName: String) -> Bool {
        self.remoteConfigSources[fileName] != nil
    }

    func configMenuStatusSubtitle(for fileName: String) -> String? {
        self.configMenuStatusSubtitleByName[fileName]
    }

    func refreshConfigMenuStatusSnapshot() {
        let now = Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: self.uiLanguage.localeIdentifier)

        var snapshot: [String: String] = [:]
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        for configURL in self.configRepository.availableConfigs {
            let fileName = configURL.lastPathComponent
            let modifiedDate = (try? configURL.resourceValues(forKeys: keys))?.contentModificationDate
            let modifiedText = self.menuRelativeTimeText(from: modifiedDate, now: now, formatter: formatter)

            let checkedText: String
            if let checkedTimestamp = self.remoteConfigLastCheckSucceededAt[fileName], checkedTimestamp > 0 {
                let checkedDate = Date(timeIntervalSince1970: checkedTimestamp)
                checkedText = self.menuRelativeTimeText(from: checkedDate, now: now, formatter: formatter)
            } else {
                checkedText = self.tr("ui.quick.config_status.never_checked")
            }

            snapshot[fileName] = self.tr("ui.quick.config_status.subtitle", modifiedText, checkedText)
        }
        self.configMenuStatusSubtitleByName = snapshot
    }

    func seedBundledConfigIfNeeded() {
        let fileManager = FileManager.default
        let targetURL = workingDirectoryManager.configDirectoryURL
            .appendingPathComponent("ClashBar.yaml", isDirectory: false)

        if fileManager.fileExists(atPath: targetURL.path) {
            return
        }

        guard let bundledConfigURL = bundledDefaultConfigURL(fileManager: fileManager) else {
            return
        }

        do {
            let data = try Data(contentsOf: bundledConfigURL)
            try writeConfigData(data, to: targetURL)
        } catch {
            appendLog(
                level: "error",
                message: tr("log.config.import_local.failed", "ClashBar.yaml", error.localizedDescription))
        }
    }

    private func bundledDefaultConfigURL(fileManager: FileManager = .default) -> URL? {
        FindBundledConfigTemplateUseCase().execute(
            resourceRoots: AppResourceBundleLocator.candidateResourceRoots(),
            fileManager: fileManager)
    }

    func selectConfig() async {
        let previousSelectedURL = configRepository.selectedConfig
        let previousSelectedPath = configRepository.selectedConfig?.path
        guard configRepository.chooseConfigDirectory() != nil else { return }

        let nextSelectedURL = configRepository.selectedConfig
        let previousCanonicalPath = previousSelectedURL?.standardizedFileURL.resolvingSymlinksInPath().path
        let nextCanonicalPath = nextSelectedURL?.standardizedFileURL.resolvingSymlinksInPath().path

        if coreRepository.isRunning,
           let nextSelectedURL,
           previousCanonicalPath != nextCanonicalPath
        {
            let validationFailure = await self.configValidationFailureDetails(configPath: nextSelectedURL.path)
            let currentCanonicalPath = self.configRepository.selectedConfig?.standardizedFileURL
                .resolvingSymlinksInPath().path
            guard currentCanonicalPath == nextCanonicalPath else { return }
            if let validationFailure {
                self.handleConfigValidationFailure(configPath: nextSelectedURL.path, details: validationFailure)
                if let previousSelectedURL {
                    configRepository.selectConfig(previousSelectedURL)
                }
                _ = self.syncSelectedConfigSelection(configRepository.selectedConfig)
                syncConfigDisplayState()
                return
            }
        }

        let nextSelectedPath = self.syncSelectedConfigSelection(configRepository.selectedConfig)
        syncConfigDisplayState()

        appendLog(level: "info", message: tr("log.config.loaded_count", configRepository.availableConfigs.count))
        await restartCoreIfNeededForConfigSwitch(previousPath: previousSelectedPath, nextPath: nextSelectedPath)
    }

    func selectConfigFile(named fileName: String) async {
        let previousSelectedURL = configRepository.selectedConfig
        let previousSelectedPath = configRepository.selectedConfig?.path
        guard let matched = configRepository.availableConfigs.first(where: { $0.lastPathComponent == fileName }) else {
            appendLog(level: "error", message: tr("log.config.not_found", fileName))
            return
        }

        let previousCanonicalPath = previousSelectedURL?.standardizedFileURL.resolvingSymlinksInPath().path
        let targetCanonicalPath = matched.standardizedFileURL.resolvingSymlinksInPath().path

        if coreRepository.isRunning,
           previousCanonicalPath != targetCanonicalPath
        {
            let validationFailure = await self.configValidationFailureDetails(configPath: matched.path)
            let currentCanonicalPath = self.configRepository.selectedConfig?.standardizedFileURL
                .resolvingSymlinksInPath().path
            // Validation runs before selecting `matched`, so stale-check against the original selection.
            guard currentCanonicalPath == previousCanonicalPath else { return }
            if let validationFailure {
                self.handleConfigValidationFailure(configPath: matched.path, details: validationFailure)
                if let previousSelectedURL {
                    configRepository.selectConfig(previousSelectedURL)
                }
                _ = self.syncSelectedConfigSelection(configRepository.selectedConfig)
                syncConfigDisplayState()
                return
            }
        }

        configRepository.selectConfig(matched)
        let nextSelectedPath = self.syncSelectedConfigSelection(matched)
        syncConfigDisplayState()
        appendLog(level: "info", message: tr("log.config.selected", fileName))
        await restartCoreIfNeededForConfigSwitch(previousPath: previousSelectedPath, nextPath: nextSelectedPath)
    }

    func importLocalConfigFile() {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }

        self.prepareModalWindowPresentation()
        let panel = NSOpenPanel()
        self.configureModalWindow(panel)
        panel.title = tr("ui.quick.import_local_config")
        panel.directoryURL = configDirectory
        var allowedTypes: [UTType] = []
        if let yamlType = UTType(filenameExtension: "yaml") {
            allowedTypes.append(yamlType)
        }
        if let ymlType = UTType(filenameExtension: "yml"), !allowedTypes.contains(ymlType) {
            allowedTypes.append(ymlType)
        }
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        guard let fileName = normalizedConfigFileName(sourceURL.lastPathComponent) else {
            appendLog(level: "error", message: tr("log.config.import.invalid_filename", sourceURL.lastPathComponent))
            return
        }

        let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
        let isOverwrite = FileManager.default.fileExists(atPath: targetURL.path)
        guard !isOverwrite || self.confirmOverwriteConfig(named: fileName) else {
            appendLog(level: "info", message: tr("log.config.import.cancelled", fileName))
            return
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            try writeConfigData(data, to: targetURL)

            self.updateRemoteConfigSource(for: fileName, urlString: nil)
            appendLog(level: "info", message: tr("log.config.import_local.success", fileName))

            if isOverwrite, self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) {
                Task { await self.reloadConfig() }
            }
        } catch {
            appendLog(
                level: "error",
                message: tr("log.config.import_local.failed", fileName, error.localizedDescription))
        }
    }

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
        let isOverwrite = FileManager.default.fileExists(atPath: targetURL.path)
        guard !isOverwrite || self.confirmOverwriteConfig(named: fileName) else {
            appendLog(level: "info", message: tr("log.config.import.cancelled", fileName))
            return
        }

        do {
            let userAgent = await remoteSubscriptionUserAgent()
            let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
            try writeConfigData(data, to: targetURL)

            self.updateRemoteConfigSource(for: fileName, urlString: remoteURL.absoluteString)
            self.markRemoteConfigCheckSucceeded(fileNames: Set([fileName]))
            let message = tr("log.config.import_remote.success", fileName)
            appendLog(level: "info", message: message)

            if isOverwrite, self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) {
                await self.reloadConfig()
            }

            self.presentRemoteConfigImportResultAlert(success: true, message: message)
        } catch {
            let message = tr("log.config.import_remote.failed", fileName, error.localizedDescription)
            appendLog(level: "error", message: message)
            self.presentRemoteConfigImportResultAlert(success: false, message: message)
        }
    }

    func updateAllRemoteConfigFiles() async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        pruneRemoteConfigSourcesIfNeeded()

        let sources = remoteConfigSources
        guard !sources.isEmpty else {
            appendLog(level: "info", message: tr("log.config.remote.no_sources"))
            return
        }

        let userAgent = await remoteSubscriptionUserAgent()
        var changedFileNames: Set<String> = []
        var succeededFileNames: Set<String> = []
        var failedCount = 0

        for fileName in sources.keys.sorted() {
            do {
                if let result = try await self.updateSingleRemoteConfigFile(
                    named: fileName,
                    configDirectory: configDirectory,
                    userAgent: userAgent)
                {
                    succeededFileNames.insert(fileName)
                    if case .changed = result {
                        changedFileNames.insert(fileName)
                    }
                } else {
                    failedCount += 1
                }
            } catch {
                failedCount += 1
                appendLog(
                    level: "error",
                    message: tr("log.config.remote.update_item_failed", fileName, error.localizedDescription))
            }
        }

        if !succeededFileNames.isEmpty {
            self.markRemoteConfigCheckSucceeded(fileNames: succeededFileNames)
        }
        self.refreshConfigStateAfterMutation()
        appendLog(level: "info", message: tr("log.config.remote.update_summary", changedFileNames.count, failedCount))

        if self.shouldAutoReloadCurrentConfig(updatedFileNames: changedFileNames) {
            await self.reloadConfig()
        }
    }

    func updateRemoteConfigFile(named fileName: String) async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        pruneRemoteConfigSourcesIfNeeded()

        guard remoteConfigSources[fileName] != nil else {
            appendLog(
                level: "error",
                message: tr("log.config.remote.update_item_failed", fileName, tr("log.config.remote.no_sources")))
            return
        }
        guard !self.remoteConfigUpdateInFlightNames.contains(fileName) else { return }

        self.remoteConfigUpdateInFlightNames.insert(fileName)
        self.remoteConfigUpdateFeedbackByName.removeValue(forKey: fileName)
        defer { self.remoteConfigUpdateInFlightNames.remove(fileName) }

        do {
            let userAgent = await remoteSubscriptionUserAgent()
            if let result = try await self.updateSingleRemoteConfigFile(
                named: fileName,
                configDirectory: configDirectory,
                userAgent: userAgent)
            {
                self.markRemoteConfigCheckSucceeded(fileNames: Set([fileName]))
                self.refreshConfigStateAfterMutation()
                if case .changed = result,
                   self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName])
                {
                    await self.reloadConfig()
                }
                self.markRemoteConfigUpdateFeedback(for: fileName, success: true)
            }
        } catch {
            appendLog(
                level: "error",
                message: tr("log.config.remote.update_item_failed", fileName, error.localizedDescription))
            self.markRemoteConfigUpdateFeedback(for: fileName, success: false)
        }
    }

    private func updateSingleRemoteConfigFile(
        named fileName: String,
        configDirectory: URL,
        userAgent: String) async throws -> RemoteConfigWriteResult?
    {
        guard let urlString = remoteConfigSources[fileName],
              let remoteURL = URL(string: urlString),
              isSupportedRemoteConfigURL(remoteURL)
        else {
            appendLog(
                level: "error",
                message: tr(
                    "log.config.remote.update_item_failed",
                    fileName,
                    tr("log.config.remote.invalid_url", remoteConfigSources[fileName] ?? fileName)))
            return nil
        }

        let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
        let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
        if let existing = try? Data(contentsOf: targetURL), existing == data {
            return .unchanged
        }
        try self.writeConfigData(data, to: targetURL)
        return .changed
    }

    private func markRemoteConfigCheckSucceeded(fileNames: Set<String>, at now: Date = Date()) {
        guard !fileNames.isEmpty else { return }
        let timestamp = now.timeIntervalSince1970
        for fileName in fileNames where self.remoteConfigSources[fileName] != nil {
            self.remoteConfigLastCheckSucceededAt[fileName] = timestamp
        }
        self.persistRemoteConfigLastCheckSucceededAt()
        self.refreshConfigMenuStatusSnapshot()
    }

    private func menuRelativeTimeText(
        from date: Date?,
        now: Date,
        formatter: RelativeDateTimeFormatter) -> String
    {
        guard let date else { return self.tr("ui.common.unknown") }
        let safeDate = min(date, now)
        if now.timeIntervalSince(safeDate) < 45 {
            return self.tr("ui.quick.config_status.just_now")
        }
        return formatter.localizedString(for: safeDate, relativeTo: now)
    }

    private func markRemoteConfigUpdateFeedback(for fileName: String, success: Bool) {
        self.remoteConfigUpdateFeedbackClearTasks[fileName]?.cancel()
        self.remoteConfigUpdateFeedbackByName[fileName] = success
        self.remoteConfigUpdateFeedbackClearTasks[fileName] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.remoteConfigUpdateFeedbackByName.removeValue(forKey: fileName)
            self.remoteConfigUpdateFeedbackClearTasks.removeValue(forKey: fileName)
        }
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

    func reloadConfig() async {
        let actionName = tr("log.action_name.reload_config")
        let expectedTunEnabled = isTunEnabled

        do {
            ensureAPIClient()
            try await self.reloadRuntimeConfigUseCase().execute(force: false)
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
        guard let selected else {
            return nil
        }
        // DRY: keep selected config state/defaults updates in one place.
        selectedConfigName = selected.lastPathComponent
        defaults.set(selected.lastPathComponent, forKey: selectedConfigKey)
        return selected.path
    }

    private func shouldAutoReloadCurrentConfig(updatedFileNames: Set<String>) -> Bool {
        guard !updatedFileNames.isEmpty else { return false }
        guard isRuntimeRunning else { return false }
        return updatedFileNames.contains(selectedConfigName)
    }

    private func writeConfigData(_ data: Data, to targetURL: URL) throws {
        try configRepository.writeConfigData(data, to: targetURL)
    }

    private func confirmOverwriteConfig(named fileName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("app.config.import.overwrite.title", fileName)
        alert.informativeText = tr("app.config.import.overwrite.message")
        alert.addButton(withTitle: tr("ui.action.overwrite"))
        alert.addButton(withTitle: tr("ui.action.cancel"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentRemoteConfigImportResultAlert(success: Bool, message: String) {
        let alert = NSAlert()
        alert.alertStyle = success ? .informational : .warning
        alert.messageText = success
            ? tr("app.config.remote_import.alert.success.title")
            : tr("app.config.remote_import.alert.failure.title")
        alert.informativeText = message
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        alert.runModal()
    }

    private struct RemoteConfigImportInput {
        let urlString: String
        let fileName: String
    }

    private func promptRemoteConfigImportInput() -> RemoteConfigImportInput? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("ui.quick.import_remote_config")
        alert.informativeText = tr("app.config.remote_import.prompt")
        alert.addButton(withTitle: tr("ui.action.import"))
        alert.addButton(withTitle: tr("ui.action.cancel"))

        // Use fixed frames in accessory view to avoid NSAlert auto-layout overlap in compact windows.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 96))

        let urlLabel = NSTextField(labelWithString: tr("ui.quick.remote.url_label"))
        urlLabel.font = .systemFont(ofSize: 12, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 76, width: 340, height: 16)

        let urlField = NSTextField(frame: NSRect(x: 0, y: 50, width: 340, height: 24))
        urlField.placeholderString = tr("ui.quick.remote.url_placeholder")

        let fileLabel = NSTextField(labelWithString: tr("ui.quick.remote.filename_label"))
        fileLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileLabel.frame = NSRect(x: 0, y: 30, width: 340, height: 16)

        let fileField = NSTextField(frame: NSRect(x: 0, y: 4, width: 340, height: 24))
        fileField.placeholderString = tr("ui.quick.remote.filename_placeholder")

        container.addSubview(urlLabel)
        container.addSubview(urlField)
        container.addSubview(fileLabel)
        container.addSubview(fileField)
        alert.accessoryView = container

        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return RemoteConfigImportInput(
            urlString: urlField.stringValue,
            fileName: fileField.stringValue)
    }

    func prepareModalWindowPresentation() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func configureModalWindow(_ window: NSWindow) {
        window.level = .statusBar
        window.collectionBehavior.insert(.moveToActiveSpace)
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

    private func remoteSubscriptionUserAgent() async -> String {
        let version = await resolvedMihomoVersionForSubscriptionUserAgent()
        return "clash.meta/\(version)"
    }

    private func resolvedMihomoVersionForSubscriptionUserAgent() async -> String {
        if let current = normalizedMihomoVersionForUserAgent(self.version) {
            return current
        }

        guard let client = try? clientOrThrow() else {
            return "unknown"
        }

        guard let fetched = try? await self.makeFetchVersionUseCase(using: client).execute() else {
            return "unknown"
        }

        let normalized = self.normalizedMihomoVersionForUserAgent(fetched.version) ?? "unknown"
        if normalized != "unknown" {
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

    private func updateRemoteConfigSource(for fileName: String, urlString: String?) {
        if let urlString {
            remoteConfigSources[fileName] = urlString
        } else {
            remoteConfigSources.removeValue(forKey: fileName)
        }
        persistRemoteConfigSources()
        self.refreshConfigStateAfterMutation()
    }
}
