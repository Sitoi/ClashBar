import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
extension AppViewModel {
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
}
