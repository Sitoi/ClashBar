import Foundation

struct PresentLogsUseCase {
    func execute(
        logs: [AppErrorLogEntry],
        selectedSources: Set<AppLogSource>,
        selectedLevels: Set<LogLevelFilter>,
        searchText: String,
        searchTextContent: (AppErrorLogEntry) -> String,
        normalizedLevel: (String) -> String,
        levelFilter: (String) -> LogLevelFilter) -> [AppErrorLogEntry]
    {
        let source = logs.prefix(120)
        let trimmedKeyword = searchText.trimmed
        let allSources = Set(AppLogSource.allCases)
        let allLevels = Set(LogLevelFilter.allCases)
        let isShowingAllSources = selectedSources == allSources
        let isShowingAllLevels = selectedLevels == allLevels

        if trimmedKeyword.isEmpty, isShowingAllSources, isShowingAllLevels {
            return Array(source)
        }

        return source.filter { log in
            guard selectedSources.contains(log.source) else { return false }
            guard trimmedKeyword.isEmpty || searchTextContent(log).localizedStandardContains(trimmedKeyword) else {
                return false
            }
            return selectedLevels.contains(levelFilter(normalizedLevel(log.level)))
        }
    }
}
