import Foundation

@MainActor
extension AppViewModel {
    func startConfigDirectoryMonitoringIfNeeded() {
        guard self.configDirectoryMonitor == nil else { return }
        guard let directoryURL = self.ensureConfigDirectoryAvailable() else { return }

        _ = self.configRepository.reloadConfigs()
        self.configFileSignatureSnapshot = Self.configFileSignatureSnapshot(for: self.configRepository.availableConfigs)
        self.configDirectoryMonitor = ConfigDirectoryMonitor(
            directoryURL: directoryURL,
            selectedFileURL: self.configRepository.selectedConfig)
        { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleConfigDirectoryRefresh()
            }
        }
    }

    func stopConfigDirectoryMonitoring() {
        self.configDirectoryMonitor?.cancel()
        self.configDirectoryMonitor = nil
        self.configDirectoryDebounceTask?.cancel()
        self.configDirectoryDebounceTask = nil
        self.configFileSignatureSnapshot = [:]
        self.pendingConfigChangeRestart = false
    }

    private func scheduleConfigDirectoryRefresh(delayNanoseconds: UInt64 = 350_000_000) {
        self.configDirectoryDebounceTask?.cancel()
        self.configDirectoryDebounceTask = Task { [weak self] in
            guard await (try? Task.sleep(nanoseconds: delayNanoseconds)) != nil else { return }
            // ponytail: release the debounce slot before handling. The core writes into the config
            // directory while restarting, and that FS event would otherwise cancel *this* task
            // mid-restart, surfacing as URLError.cancelled on the system-proxy restore.
            self?.configDirectoryDebounceTask = nil
            await self?.handleConfigDirectoryChangesIfNeeded()
        }
    }

    private func handleConfigDirectoryChangesIfNeeded() async {
        guard let directoryURL = self.ensureConfigDirectoryAvailable() else { return }

        let previousSelectedPath = self.configRepository.selectedConfig?.path
        let scan = await Task.detached(priority: .utility) {
            let files = ConfigDirectoryManager.scanConfigFiles(in: directoryURL)
            let signatures = Self.configFileSignatureSnapshot(for: files)
            return (files, signatures)
        }.value
        guard !Task.isCancelled else { return }

        let changedFileNames = self.changedConfigFileNames(
            previous: self.configFileSignatureSnapshot,
            current: scan.1)
        var selectedConfigChanged = false
        if !changedFileNames.isEmpty {
            self.configRepository.applyScannedConfigs(scan.0)
            self.configFileSignatureSnapshot = scan.1
            let nextSelectedPath = self.syncSelectedConfigStateForMonitoring()
            self.syncConfigDisplayState()

            let involvedSelectedFileNames = Set([
                self.configFileName(fromPath: previousSelectedPath),
                self.configFileName(fromPath: nextSelectedPath),
            ].compactMap(\.self))
            selectedConfigChanged = !involvedSelectedFileNames.isDisjoint(with: changedFileNames)
        }

        guard !self.isRemoteTarget else {
            self.pendingConfigChangeRestart = false
            return
        }
        guard self.pendingConfigChangeRestart || selectedConfigChanged else { return }
        guard self.isRuntimeRunning else {
            self.pendingConfigChangeRestart = false
            return
        }

        if self.isCoreActionProcessing {
            if selectedConfigChanged, !self.isTunSyncing {
                self.pendingConfigChangeRestart = true
            }
            self.scheduleConfigDirectoryRefresh(delayNanoseconds: 500_000_000)
            return
        }

        self.pendingConfigChangeRestart = false
        self.appendLog(level: "info", message: self.tr("log.config.changed_restart"))
        await self.restartCore(trigger: .configSwitch)
    }

    private nonisolated static func configFileSignatureSnapshot(for files: [URL]) -> [String: String] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        var snapshot: [String: String] = [:]

        for fileURL in files {
            let resolved = fileURL.resolvingSymlinksInPath()
            let values = try? resolved.resourceValues(forKeys: keys)
            let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            let size = values?.fileSize ?? -1
            snapshot[fileURL.lastPathComponent] = "\(modifiedAt)-\(size)"
        }

        return snapshot
    }

    private func changedConfigFileNames(
        previous: [String: String],
        current: [String: String]) -> Set<String>
    {
        let allNames = Set(previous.keys).union(current.keys)
        return Set(allNames.filter { previous[$0] != current[$0] })
    }

    private func configFileName(fromPath path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    @discardableResult
    private func syncSelectedConfigStateForMonitoring() -> String? {
        guard let path = self.syncSelectedConfigSelection(self.configRepository.selectedConfig) else {
            self.selectedConfigName = "-"
            self.defaults.removeObject(forKey: self.selectedConfigKey)
            return nil
        }
        return path
    }
}
