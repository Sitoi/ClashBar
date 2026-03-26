import Foundation
import SwiftUI

@MainActor
final class LogsTabViewModel: ObservableObject {
    private let presentLogsUseCase: PresentLogsUseCase

    @Published var selectedSources: Set<AppLogSource> = []
    @Published var selectedLevels: Set<LogLevelFilter> = []
    @Published var searchText: String = ""
    @Published private(set) var visibleLogs: [AppErrorLogEntry] = []

    init(presentLogsUseCase: PresentLogsUseCase = PresentLogsUseCase()) {
        self.presentLogsUseCase = presentLogsUseCase
    }

    func toggleSource(_ source: AppLogSource) {
        self.toggleSelection(source, selection: &self.selectedSources)
    }

    func toggleLevel(_ level: LogLevelFilter) {
        self.toggleSelection(level, selection: &self.selectedLevels)
    }

    func updateVisibleLogs(
        from logs: [AppErrorLogEntry],
        searchTextContent: @escaping (AppErrorLogEntry) -> String,
        normalizedLevel: @escaping (String) -> String,
        levelFilter: @escaping (String) -> LogLevelFilter)
    {
        let nextLogs = self.presentLogsUseCase.execute(.init(
            logs: logs,
            selectedSources: self.selectedSources,
            selectedLevels: self.selectedLevels,
            searchText: self.searchText,
            searchTextContent: searchTextContent,
            normalizedLevel: normalizedLevel,
            levelFilter: levelFilter))
        guard nextLogs != self.visibleLogs else { return }
        self.visibleLogs = nextLogs
    }

    private func toggleSelection<Value: Hashable>(
        _ value: Value,
        selection: inout Set<Value>)
    {
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
    }
}
