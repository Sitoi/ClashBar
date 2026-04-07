import Foundation

@MainActor
extension AppSession {
    // MARK: - Auto-Update Task

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
            await refreshRemoteConfigFile(named: fileName)
        }
    }

    // MARK: - Menu Refresh Timer

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
