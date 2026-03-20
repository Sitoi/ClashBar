import Foundation
import SwiftUI

@MainActor
final class LogsTabViewModel: ObservableObject {
    private let presentLogsUseCase: PresentLogsUseCase

    @Published var selectedSources: Set<AppLogSource> = Set(AppLogSource.allCases)
    @Published var selectedLevels: Set<LogLevelFilter> = [.info, .warning, .error]
    @Published var searchText: String = ""
    @Published private(set) var visibleLogs: [AppErrorLogEntry] = []

    init(presentLogsUseCase: PresentLogsUseCase = PresentLogsUseCase()) {
        self.presentLogsUseCase = presentLogsUseCase
    }

    var allSourceSelection: Set<AppLogSource> {
        Set(AppLogSource.allCases)
    }

    var allLevelSelection: Set<LogLevelFilter> {
        Set(LogLevelFilter.allCases)
    }

    var trimmedKeyword: String {
        self.searchText.trimmed
    }

    var hasActiveFilters: Bool {
        self.selectedSources != self.allSourceSelection ||
            self.selectedLevels != self.allLevelSelection ||
            !self.trimmedKeyword.isEmpty
    }

    func selectAllSources() {
        self.selectedSources = self.allSourceSelection
    }

    func selectAllLevels() {
        self.selectedLevels = self.allLevelSelection
    }

    func resetFilters() {
        self.selectAllSources()
        self.selectAllLevels()
        self.searchText = ""
    }

    func toggleSource(_ source: AppLogSource) {
        self.toggleSelection(source, selection: &self.selectedSources, all: self.allSourceSelection)
    }

    func toggleLevel(_ level: LogLevelFilter) {
        self.toggleSelection(level, selection: &self.selectedLevels, all: self.allLevelSelection)
    }

    func updateVisibleLogs(
        from logs: [AppErrorLogEntry],
        searchTextContent: (AppErrorLogEntry) -> String,
        normalizedLevel: (String) -> String,
        levelFilter: (String) -> LogLevelFilter)
    {
        let nextLogs = self.presentLogsUseCase.execute(
            logs: logs,
            selectedSources: self.selectedSources,
            selectedLevels: self.selectedLevels,
            searchText: self.searchText,
            searchTextContent: searchTextContent,
            normalizedLevel: normalizedLevel,
            levelFilter: levelFilter)
        guard nextLogs != self.visibleLogs else { return }
        self.visibleLogs = nextLogs
    }

    private func toggleSelection<Value: Hashable>(
        _ value: Value,
        selection: inout Set<Value>,
        all: Set<Value>)
    {
        if selection.contains(value) {
            selection.remove(value)
            if selection.isEmpty {
                selection = all
            }
        } else {
            selection.insert(value)
        }
    }
}
