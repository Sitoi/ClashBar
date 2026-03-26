import Foundation

@MainActor
extension AppSession {
    private var configDirectoryMonitorIntervalNanoseconds: UInt64 {
        1_000_000_000
    }

    func startConfigDirectoryMonitoringIfNeeded() {
        guard self.configDirectoryMonitorTask == nil else { return }
        guard self.ensureConfigDirectoryAvailable() != nil else { return }

        _ = self.configRepository.reloadConfigs()
        self.configFileSignatureSnapshot = self.currentConfigFileSignatureSnapshot()

        self.configDirectoryMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: self.configDirectoryMonitorIntervalNanoseconds)
                } catch {
                    return
                }
                await self.handleConfigDirectoryChangesIfNeeded()
            }
        }
    }

    func stopConfigDirectoryMonitoring() {
        self.configDirectoryMonitorTask?.cancel()
        self.configDirectoryMonitorTask = nil
        self.configFileSignatureSnapshot = [:]
        self.pendingConfigChangeRestart = false
    }

    private func handleConfigDirectoryChangesIfNeeded() async {
        guard !self.isRemoteTarget else { return }

        if self.pendingConfigChangeRestart,
           self.isRuntimeRunning,
           !self.isCoreActionProcessing
        {
            self.pendingConfigChangeRestart = false
            self.appendLog(level: "info", message: self.tr("log.config.changed_restart"))
            await self.restartCore(trigger: .configSwitch)
            return
        }

        guard self.ensureConfigDirectoryAvailable() != nil else { return }

        let previousSelectedPath = self.configRepository.selectedConfig?.path
        _ = self.configRepository.reloadConfigs()
        let currentSnapshot = self.currentConfigFileSignatureSnapshot()

        if self.configFileSignatureSnapshot.isEmpty {
            self.configFileSignatureSnapshot = currentSnapshot
            return
        }

        let changedFileNames = self.changedConfigFileNames(
            previous: self.configFileSignatureSnapshot,
            current: currentSnapshot)
        guard !changedFileNames.isEmpty else { return }

        self.configFileSignatureSnapshot = currentSnapshot
        let nextSelectedPath = self.syncSelectedConfigStateForMonitoring()
        self.syncConfigDisplayState()

        let involvedSelectedFileNames = Set([
            self.configFileName(fromPath: previousSelectedPath),
            self.configFileName(fromPath: nextSelectedPath),
        ].compactMap(\.self))
        guard !involvedSelectedFileNames.isDisjoint(with: changedFileNames) else { return }
        guard self.isRuntimeRunning else { return }

        if self.isCoreActionProcessing {
            // Skip restart chaining for in-flight TUN operations; those already include a controlled restart.
            if !self.isTunSyncing {
                self.pendingConfigChangeRestart = true
            }
            return
        }

        self.appendLog(level: "info", message: self.tr("log.config.changed_restart"))
        await self.restartCore(trigger: .configSwitch)
    }

    private func currentConfigFileSignatureSnapshot() -> [String: String] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        var snapshot: [String: String] = [:]

        for fileURL in self.configRepository.availableConfigs {
            let values = try? fileURL.resourceValues(forKeys: keys)
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
        guard let selected = self.configRepository.selectedConfig else {
            self.selectedConfigName = "-"
            self.defaults.removeObject(forKey: self.selectedConfigKey)
            return nil
        }

        self.selectedConfigName = selected.lastPathComponent
        self.defaults.set(selected.lastPathComponent, forKey: self.selectedConfigKey)
        return selected.path
    }
}
