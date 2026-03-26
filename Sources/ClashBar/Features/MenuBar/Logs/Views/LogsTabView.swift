import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

private struct LogsFilterChipButton: View {
    let title: String
    let selected: Bool
    let selectedFill: Color
    let selectedBorder: Color
    let selectedText: Color
    let normalText: Color
    let hoverFill: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, T.space6)
                .padding(.vertical, T.space2)
                .foregroundStyle(self.selected ? self.selectedText : self.normalText)
                .background {
                    Capsule(style: .continuous)
                        .fill(self.selected ? self.selectedFill : (self.isHovered ? self.hoverFill : .clear))
                        .overlay {
                            if self.selected {
                                Capsule(style: .continuous)
                                    .stroke(self.selectedBorder, lineWidth: T.stroke)
                            }
                        }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: self.isHovered)
        .animation(.snappy(duration: 0.16), value: self.selected)
    }
}

private struct LogFilterGroupConfiguration<Item: Hashable> {
    let symbol: String
    let allTitle: String
    let allSelected: Bool
    let selectAll: () -> Void
    let items: [Item]
    let itemTitle: (Item) -> String
    let itemSelected: (Item) -> Bool
    let toggleItem: (Item) -> Void
}

extension MenuBarRootView {
    var logsTabBody: some View {
        let logs = self.logsViewModel.visibleLogs

        return VStack(alignment: .leading, spacing: T.space6) {
            self.logsControlCard(filteredCount: logs.count)

            if logs.isEmpty {
                emptyCard(tr("ui.empty.logs"))
            } else {
                MeasurementAwareVStack(alignment: .leading, spacing: 0) {
                    SeparatedForEach(data: logs, id: \.id, separator: nativeSeparator) { log in
                        self.logEntryRow(log)
                            .padding(.horizontal, T.space4)
                            .padding(.vertical, T.space4)
                    }
                }
            }
        }
    }

    func logsControlCard(filteredCount: Int) -> some View {
        VStack(alignment: .leading, spacing: T.space4) {
            HStack(spacing: T.space6) {
                self.logsSourceFilterButtons

                Spacer(minLength: 0)

                self.fractionSummaryBadge(current: filteredCount, total: appSession.errorLogs.count)
            }
            self.logsSecondaryControlRow
            TextField(tr("ui.placeholder.search_logs"), text: $logsViewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: T.FontSize.body, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
        }
        .menuRowPadding(vertical: T.space4)
    }

    var logsSecondaryControlRow: some View {
        HStack(spacing: T.space6) {
            self.logsLevelFilterButtons

            Spacer(minLength: 0)

            self.compactTopIcon(
                "doc.on.doc",
                label: tr("ui.action.copy_all_logs"),
                toneOverride: nativeSecondaryLabel)
            {
                appSession.copyAllLogs()
            }
            .help(tr("ui.action.copy_all_logs"))
            .disabled(appSession.errorLogs.isEmpty)

            self.compactTopIcon(
                "trash",
                label: tr("ui.action.clear_all_logs"),
                role: .destructive,
                warning: true)
            {
                appSession.clearAllLogs()
            }
            .help(tr("ui.action.clear_all_logs"))
            .disabled(appSession.errorLogs.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var logsSourceFilterButtons: some View {
        self.logFilterGroup(.init(
            symbol: "line.3.horizontal.decrease.circle",
            allTitle: tr("ui.log_source.all"),
            allSelected: false,
            selectAll: { self.logsViewModel.selectedSources = [] },
            items: AppLogSource.allCases,
            itemTitle: { self.logSourcePresentation($0).label },
            itemSelected: { self.logsViewModel.selectedSources.contains($0) },
            toggleItem: { self.logsViewModel.toggleSource($0) }))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var logsLevelFilterButtons: some View {
        self.logFilterGroup(.init(
            symbol: "slider.horizontal.3",
            allTitle: tr("ui.log_filter.all"),
            allSelected: false,
            selectAll: { self.logsViewModel.selectedLevels = [] },
            items: LogLevelFilter.allCases,
            itemTitle: { tr($0.titleKey) },
            itemSelected: { self.logsViewModel.selectedLevels.contains($0) },
            toggleItem: { self.logsViewModel.toggleLevel($0) }))
    }

    private func logFilterGroup(
        _ configuration: LogFilterGroupConfiguration<some Hashable>) -> some View
    {
        HStack(spacing: T.space2) {
            Image(systemName: configuration.symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)

            self.logFilterToggleButton(
                title: configuration.allTitle,
                selected: configuration.allSelected,
                action: configuration.selectAll)

            ForEach(configuration.items, id: \.self) { item in
                self.logFilterToggleButton(
                    title: configuration.itemTitle(item),
                    selected: configuration.itemSelected(item),
                    action: { configuration.toggleItem(item) })
            }
        }
    }

    func logFilterToggleButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void) -> some View
    {
        LogsFilterChipButton(
            title: title,
            selected: selected,
            selectedFill: self.nativeAccent
                .opacity(self.isDarkAppearance ? 0.10 : 0.045),
            selectedBorder: self.nativeAccent
                .opacity(self.isDarkAppearance ? 0.14 : 0.08),
            selectedText: self.nativePrimaryLabel
                .opacity(self.isDarkAppearance ? 0.96 : 0.88),
            normalText: self.nativeSecondaryLabel,
            hoverFill: self.nativeHoverFill
                .opacity(self.isDarkAppearance ? 0.06 : 0.035),
            action: action)
    }

    func refreshVisibleLogs() {
        self.logsViewModel.updateVisibleLogs(
            from: self.appSession.errorLogs,
            searchTextContent: { log in self.logSearchTextContent(for: log) },
            normalizedLevel: { level in self.normalizedLogLevel(level) },
            levelFilter: { level in self.logLevelFilter(level) })
    }

    func logEntryRow(_ log: AppErrorLogEntry) -> some View {
        let level = self.normalizedLogLevel(log.level)
        let sourceInfo = self.logSourcePresentation(log.source)
        let levelInfo = self.logLevelPresentation(level)
        let parsed = self.parseLogMessage(log.message)
        let tone = levelInfo.color
        let symbol = levelInfo.symbol

        return HStack(alignment: .center, spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: T.rowLeadingIcon, height: T.rowLeadingIcon)

            VStack(alignment: .leading, spacing: T.space2) {
                HStack(spacing: T.space2) {
                    Text(sourceInfo.label)
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(sourceInfo.color)

                    if let protocolTag = parsed.protocolTag {
                        self.logMetadataSeparator
                        Text(protocolTag)
                            .font(.app(size: T.FontSize.caption, weight: .semibold))
                            .foregroundStyle(parsed.protocolColor)
                    }

                    self.logMetadataSeparator
                    Text(ValueFormatter.dateTime(log.timestamp))
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeTertiaryLabel)
                        .lineLimit(1)
                }

                Text(parsed.mainText)
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativePrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailText = parsed.detailText {
                    Text(detailText)
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeSecondaryLabel)
                        .lineLimit(2)
                        .padding(.leading, T.space6)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(tone.opacity(T.Opacity.tint))
                                .frame(width: T.space1)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button {
                appSession.copyLogMessage(log)
            } label: {
                Label(tr("ui.action.copy_log_message"), systemImage: "doc.on.doc")
            }

            Button {
                appSession.copyLogEntry(log)
            } label: {
                Label(tr("ui.action.copy_log_entry"), systemImage: "doc.plaintext")
            }
        }
    }

    var logMetadataSeparator: some View {
        Text("•")
            .font(.app(size: T.FontSize.caption, weight: .regular))
            .foregroundStyle(nativeTertiaryLabel)
    }

    func normalizedLogLevel(_ raw: String) -> String {
        let lower = raw.trimmed.lowercased()
        if lower.contains("error") || lower.contains("err") {
            return "ERROR"
        }
        if lower.contains("warn") {
            return "WARNING"
        }
        return "INFO"
    }

    func logSourcePresentation(_ source: AppLogSource) -> (label: String, color: Color) {
        switch source {
        case .clashbar:
            (tr("ui.log_source.clashbar"), nativeSecondaryLabel)
        case .mihomo:
            (tr("ui.log_source.mihomo"), nativeAccent.opacity(T.Opacity.solid))
        }
    }

    func logLevelPresentation(_ normalizedLevel: String)
        -> (filter: LogLevelFilter, label: String, color: Color, symbol: String)
    {
        let filter = self.logLevelFilter(normalizedLevel)
        switch filter {
        case .error:
            return (
                LogLevelFilter.error,
                tr("ui.log_filter.error"),
                nativeCritical.opacity(T.Opacity.solid),
                "exclamationmark.octagon.fill")
        case .warning:
            return (
                LogLevelFilter.warning,
                tr("ui.log_filter.warning"),
                nativeWarning.opacity(T.Opacity.solid),
                "exclamationmark.triangle.fill")
        case .info:
            return (
                LogLevelFilter.info,
                tr("ui.log_filter.info"),
                nativeAccent.opacity(T.Opacity.solid),
                "info.circle.fill")
        }
    }

    func logLevelFilter(_ normalizedLevel: String) -> LogLevelFilter {
        switch normalizedLevel {
        case "ERROR":
            .error
        case "WARNING":
            .warning
        default:
            .info
        }
    }

    func parseLogMessage(_ raw: String)
    -> (protocolTag: String?, protocolColor: Color, mainText: String, detailText: String?) {
        var message = raw.trimmed
        if message.isEmpty {
            return (nil, nativeSecondaryLabel, tr("ui.common.na"), nil)
        }

        if let extracted = firstRegexCapture(in: message, regex: CachedLogRegex.msgField), !extracted.isEmpty {
            message = extracted
        }

        var detailText: String?
        if let trailingBracket = firstRegexCapture(in: message, regex: CachedLogRegex.trailingBracket) {
            detailText = trailingBracket
            message = message.replacingOccurrences(of: trailingBracket, with: "").trimmed
        }

        var protocolTag: String?
        var protocolColor = nativeAccent.opacity(T.Opacity.solid)
        if let tag = firstRegexCapture(in: message, regex: CachedLogRegex.protocolTag) {
            protocolTag = tag
            message = message.replacingOccurrences(of: tag, with: "").trimmed

            let upper = tag.uppercased()
            if upper.contains("UDP") { protocolColor = nativeWarning.opacity(T.Opacity.solid) }
            if upper.contains("DNS") { protocolColor = nativePositive.opacity(T.Opacity.solid) }
            if upper.contains("HTTP") { protocolColor = nativeAccent.opacity(T.Opacity.solid) }
        }

        if message.isEmpty {
            message = raw.trimmed
        }
        return (protocolTag, protocolColor, message, detailText)
    }

    func firstRegexCapture(in text: String, regex: NSRegularExpression?) -> String? {
        guard let regex else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return nil }
        return nsText.substring(with: captureRange)
    }

    func logSearchTextContent(for log: AppErrorLogEntry) -> String {
        let source = self.logSourcePresentation(log.source).label
        let level = self.normalizedLogLevel(log.level)
        let time = ValueFormatter.dateTime(log.timestamp)
        let message = log.message
        return "\(source) \(level) \(time) \(message)"
    }
}

private enum CachedLogRegex {
    static let msgField = try? NSRegularExpression(pattern: #"msg="([^"]+)""#, options: [])
    static let trailingBracket = try? NSRegularExpression(pattern: #"(?:\s|^)(\[[^\[\]]+\])\s*$"#, options: [])
    static let protocolTag = try? NSRegularExpression(pattern: #"(\[(?:TCP|UDP|DNS|HTTP|HTTPS)\])"#, options: [])
}
