import Foundation

struct PresentLogsUseCase {
    struct Input {
        let logs: [AppErrorLogEntry]
        let selectedSources: Set<AppLogSource>
        let selectedLevels: Set<LogLevelFilter>
        let searchText: String
        let searchTextContent: (AppErrorLogEntry) -> String
        let normalizedLevel: (String) -> String
        let levelFilter: (String) -> LogLevelFilter
    }

    func execute(_ input: Input) -> [AppErrorLogEntry] {
        let source = input.logs.prefix(120)
        let trimmedKeyword = input.searchText.trimmed
        let isShowingAllSources = input.selectedSources.isEmpty
        let isShowingAllLevels = input.selectedLevels.isEmpty

        if trimmedKeyword.isEmpty, isShowingAllSources, isShowingAllLevels {
            return Array(source)
        }

        return source.filter { log in
            guard isShowingAllSources || input.selectedSources.contains(log.source) else { return false }
            guard trimmedKeyword.isEmpty || input.searchTextContent(log).localizedStandardContains(trimmedKeyword)
            else {
                return false
            }
            return isShowingAllLevels || input.selectedLevels
                .contains(input.levelFilter(input.normalizedLevel(log.level)))
        }
    }
}
