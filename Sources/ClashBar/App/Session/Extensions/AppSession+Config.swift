import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
extension AppSession {
    private func reloadRuntimeConfigUseCase() throws -> ReloadRuntimeConfigUseCase {
        try ReloadRuntimeConfigUseCase(repository: DefaultRuntimeConfigRepository(transport: self.clientOrThrow()))
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

            self.removeRemoteConfigSubscription(for: fileName)
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
        let existsAlready = FileManager.default.fileExists(atPath: targetURL.path)
        let existingIsRemote = self.remoteConfigSubscriptions[fileName] != nil

        // Skip overwrite confirmation if the file is already a remote subscription;
        // show it only when overwriting a local config file.
        if existsAlready, !existingIsRemote {
            guard self.confirmOverwriteConfig(named: fileName) else {
                appendLog(level: "info", message: tr("log.config.import.cancelled", fileName))
                return
            }
        }

        do {
            let userAgent = await remoteSubscriptionUserAgent()
            let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
            try writeConfigData(data, to: targetURL)

            let subscription = RemoteConfigSubscription(
                urlString: remoteURL.absoluteString,
                autoUpdateEnabled: input.autoUpdateEnabled,
                autoUpdateIntervalHours: input.autoUpdateIntervalHours,
                lastUpdateCheckAt: Date())
            self.upsertRemoteConfigSubscription(for: fileName, subscription: subscription)
            let message = tr("log.config.import_remote.success", fileName)
            appendLog(level: "info", message: message)

            if existsAlready, self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) {
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
        pruneRemoteConfigSubscriptionsIfNeeded()

        let subscriptions = remoteConfigSubscriptions
        guard !subscriptions.isEmpty else {
            appendLog(level: "info", message: tr("log.config.remote.no_sources"))
            return
        }

        let userAgent = await remoteSubscriptionUserAgent()
        var updatedFileNames: Set<String> = []
        var failedCount = 0

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
                try self.writeConfigData(data, to: targetURL)
                self.remoteConfigSubscriptions[fileName] = refreshedSubscription
                updatedFileNames.insert(fileName)
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
        self.refreshConfigStateAfterMutation()
        appendLog(level: "info", message: tr("log.config.remote.update_summary", updatedFileNames.count, failedCount))

        if self.shouldAutoReloadCurrentConfig(updatedFileNames: updatedFileNames) {
            await self.reloadConfig()
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
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("app.config.delete.title", fileName)
        alert.informativeText = tr("app.config.delete.message")
        alert.addButton(withTitle: tr("ui.action.delete"))
        alert.addButton(withTitle: tr("ui.action.cancel"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        return alert.runModal() == .alertFirstButtonReturn
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
            try self.writeConfigData(data, to: targetURL)

            self.remoteConfigSubscriptions[fileName] = refreshedSubscription
            self.persistRemoteConfigSubscriptions()
            self.refreshConfigStateAfterMutation()

            if self.shouldAutoReloadCurrentConfig(updatedFileNames: [fileName]) {
                await self.reloadConfig()
            }

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
        guard !isRemoteTarget else { return false }
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
        let autoUpdateEnabled: Bool
        let autoUpdateIntervalHours: Int
    }

    private func promptRemoteConfigImportInput() -> RemoteConfigImportInput? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("ui.quick.import_remote_config")
        alert.informativeText = tr("app.config.remote_import.prompt")
        alert.addButton(withTitle: tr("ui.action.import"))
        alert.addButton(withTitle: tr("ui.action.cancel"))

        // Use fixed frames in accessory view to avoid NSAlert auto-layout overlap in compact windows.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 142))

        let urlLabel = NSTextField(labelWithString: tr("ui.quick.remote.url_label"))
        urlLabel.font = .systemFont(ofSize: 12, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 124, width: 340, height: 16)

        let urlField = NSTextField(frame: NSRect(x: 0, y: 98, width: 340, height: 24))
        urlField.placeholderString = tr("ui.quick.remote.url_placeholder")

        let fileLabel = NSTextField(labelWithString: tr("ui.quick.remote.filename_label"))
        fileLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileLabel.frame = NSRect(x: 0, y: 76, width: 340, height: 16)

        let fileField = NSTextField(frame: NSRect(x: 0, y: 50, width: 340, height: 24))
        fileField.placeholderString = tr("ui.quick.remote.filename_placeholder")

        // Visual separator between file info and auto-update settings
        let separator = NSBox(frame: NSRect(x: 0, y: 38, width: 340, height: 1))
        separator.boxType = .separator

        // Auto-update row: checkbox on the left, interval controls on the right
        let autoUpdateCheckbox = NSButton(
            checkboxWithTitle: tr("ui.quick.remote.auto_update_label"),
            target: nil,
            action: nil)
        autoUpdateCheckbox.frame = NSRect(x: 0, y: 8, width: 140, height: 22)
        autoUpdateCheckbox.state = .on

        let intervalUnit = NSTextField(labelWithString: tr("ui.quick.remote.interval_unit"))
        intervalUnit.font = .systemFont(ofSize: 12, weight: .regular)
        intervalUnit.textColor = .secondaryLabelColor
        intervalUnit.frame = NSRect(x: 306, y: 12, width: 34, height: 16)

        let intervalField = NSTextField(frame: NSRect(x: 252, y: 8, width: 50, height: 22))
        intervalField.stringValue = "\(RemoteConfigSubscription.defaultAutoUpdateIntervalHours)"
        intervalField.alignment = .center

        let eachLabel = NSTextField(labelWithString: tr("ui.quick.remote.interval_each"))
        eachLabel.font = .systemFont(ofSize: 12, weight: .regular)
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
        alert.accessoryView = container

        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

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
        try await self.applyTunRuntimeChange(enabled: expectedEnabled)
        if isTunEnabled != expectedEnabled {
            isTunEnabled = expectedEnabled
            persistEditableSettingsSnapshot()
        }
    }

    private func upsertRemoteConfigSubscription(for fileName: String, subscription: RemoteConfigSubscription) {
        remoteConfigSubscriptions[fileName] = subscription
        persistRemoteConfigSubscriptions()
        restartRemoteConfigBackgroundTasksIfNeeded()
        self.refreshConfigStateAfterMutation()
    }

    private func removeRemoteConfigSubscription(for fileName: String) {
        guard remoteConfigSubscriptions[fileName] != nil else { return }
        remoteConfigSubscriptions.removeValue(forKey: fileName)
        persistRemoteConfigSubscriptions()
        restartRemoteConfigBackgroundTasksIfNeeded()
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
}
