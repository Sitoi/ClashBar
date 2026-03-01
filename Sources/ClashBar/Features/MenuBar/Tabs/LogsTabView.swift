import Foundation
import SwiftUI

extension MenuBarRoot {
    var logsTabBody: some View {
        let logs = filteredLogs

        return VStack(alignment: .leading, spacing: MenuBarLayoutTokens.sectionGap) {
            logsControlCard

            if logs.isEmpty {
                emptyCard(tr("ui.empty.logs"))
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        logEntryRow(log)
                            .padding(.horizontal, MenuBarLayoutTokens.hRow)
                            .padding(.vertical, MenuBarLayoutTokens.vDense + 2)

                        if index < logs.count - 1 {
                            Rectangle()
                                .fill(nativeSeparator)
                                .frame(height: MenuBarLayoutTokens.hairline)
                        }
                    }
                }
                .background(nativeSectionCard())
            }
        }
    }

    var logsControlCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.vDense + 2) {
            HStack(spacing: MenuBarLayoutTokens.hDense) {
                Text(tr("ui.tab.logs"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(nativeTertiaryLabel)

                Text("\(filteredLogs.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(nativeBadgeCapsule())

                Spacer(minLength: 0)

                Button {
                    appState.copyAllLogs()
                } label: {
                    Label(tr("ui.action.copy_all_logs"), systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.errorLogs.isEmpty)

                Button(role: .destructive) {
                    appState.clearAllLogs()
                } label: {
                    Label(tr("ui.action.clear_all_logs"), systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.errorLogs.isEmpty)

                AttachedPopoverMenu {
                    HStack(spacing: MenuBarLayoutTokens.hMicro + 1) {
                        Text(tr(logSourceFilter.titleKey))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(nativePrimaryLabel)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(nativeTertiaryLabel)
                    }
                } content: { dismiss in
                    ForEach(LogSourceFilter.allCases) { option in
                        AttachedPopoverMenuItem(
                            title: tr(option.titleKey),
                            selected: option == logSourceFilter
                        ) {
                            logSourceFilter = option
                            dismiss()
                        }
                    }
                }
                .fixedSize()
                .buttonStyle(.bordered)

                AttachedPopoverMenu {
                    HStack(spacing: MenuBarLayoutTokens.hMicro + 1) {
                        Text(tr(logLevelFilter.titleKey))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(nativePrimaryLabel)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(nativeTertiaryLabel)
                    }
                } content: { dismiss in
                    ForEach(LogLevelFilter.allCases) { option in
                        AttachedPopoverMenuItem(
                            title: tr(option.titleKey),
                            selected: option == logLevelFilter
                        ) {
                            logLevelFilter = option
                            dismiss()
                        }
                    }
                }
                .fixedSize()
                .buttonStyle(.bordered)
            }

            TextField(tr("ui.placeholder.search_logs"), text: $logSearchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.vDense + 2)
        .background(nativeSectionCard())
    }

    var filteredLogs: [AppErrorLogEntry] {
        let logs = Array(appState.errorLogs.prefix(120))
        let keyword = logSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return logs.filter { log in
            let sourceMatched = logSourceFilter.matches(source: log.source)
            guard sourceMatched else { return false }
            let levelMatched = logLevelFilter.matches(level: normalizedLogLevel(log.level))
            guard levelMatched else { return false }
            guard !keyword.isEmpty else { return true }
            return logSearchTextContent(for: log).localizedStandardContains(keyword)
        }
    }

    func logEntryRow(_ log: AppErrorLogEntry) -> some View {
        let level = normalizedLogLevel(log.level)
        let sourceLabel = localizedLogSourceLabel(log.source)
        let sourceTone = logSourceStyle(log.source)
        let displayLevel = localizedLogLevelLabel(level)
        let parsed = parseLogMessage(log.message)
        let tone = logLevelStyle(level)
        let symbol = logLevelSymbol(level)

        return HStack(alignment: .top, spacing: MenuBarLayoutTokens.hDense + 1) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tone.opacity(0.14))
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tone)
                }

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.vDense) {
                HStack(spacing: MenuBarLayoutTokens.hMicro + 1) {
                    Text("[\(sourceLabel)]")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(sourceTone)

                    Text("[\(displayLevel)]")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tone)

                    if let protocolTag = parsed.protocolTag {
                        Text(protocolTag)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(parsed.protocolColor)
                    }

                    Text(ValueFormatter.dateTime(log.timestamp))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(nativeTertiaryLabel)
                        .lineLimit(1)
                }

                Text(parsed.mainText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(nativePrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailText = parsed.detailText {
                    Text(detailText)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(nativeSecondaryLabel)
                        .lineLimit(2)
                        .padding(.leading, MenuBarLayoutTokens.hDense)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(tone.opacity(0.30))
                                .frame(width: MenuBarLayoutTokens.opticalNudge)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button {
                appState.copyLogMessage(log)
            } label: {
                Label(tr("ui.action.copy_log_message"), systemImage: "doc.on.doc")
            }

            Button {
                appState.copyLogEntry(log)
            } label: {
                Label(tr("ui.action.copy_log_entry"), systemImage: "doc.plaintext")
            }
        }
    }

    func normalizedLogLevel(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("error") || lower.contains("err") {
            return "ERROR"
        }
        if lower.contains("warn") {
            return "WARNING"
        }
        return "INFO"
    }

    func localizedLogLevelLabel(_ level: String) -> String {
        switch level {
        case "ERROR":
            return tr("ui.log_filter.error")
        case "WARNING":
            return tr("ui.log_filter.warning")
        default:
            return tr("ui.log_filter.info")
        }
    }

    func localizedLogSourceLabel(_ source: AppLogSource) -> String {
        switch source {
        case .clashbar:
            return tr("ui.log_source.clashbar")
        case .mihomo:
            return tr("ui.log_source.mihomo")
        }
    }

    func logSourceStyle(_ source: AppLogSource) -> Color {
        switch source {
        case .clashbar:
            return nativeSecondaryLabel
        case .mihomo:
            return nativeAccent.opacity(0.95)
        }
    }

    func logLevelStyle(_ level: String) -> Color {
        switch level {
        case "ERROR":
            return nativeCritical.opacity(0.92)
        case "WARNING":
            return nativeWarning.opacity(0.92)
        default:
            return nativeAccent.opacity(0.9)
        }
    }

    func logLevelSymbol(_ level: String) -> String {
        switch level {
        case "ERROR":
            return "exclamationmark.octagon.fill"
        case "WARNING":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    func parseLogMessage(_ raw: String) -> (protocolTag: String?, protocolColor: Color, mainText: String, detailText: String?) {
        var message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            return (nil, nativeSecondaryLabel, tr("ui.common.na"), nil)
        }

        if let extracted = firstRegexCapture(in: message, regex: CachedLogRegex.msgField), !extracted.isEmpty {
            message = extracted
        }

        var detailText: String?
        if let trailingBracket = firstRegexCapture(in: message, regex: CachedLogRegex.trailingBracket) {
            detailText = trailingBracket
            message = message.replacingOccurrences(of: trailingBracket, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var protocolTag: String?
        var protocolColor = nativeAccent.opacity(0.90)
        if let tag = firstRegexCapture(in: message, regex: CachedLogRegex.protocolTag) {
            protocolTag = tag
            message = message.replacingOccurrences(of: tag, with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            let upper = tag.uppercased()
            if upper.contains("UDP") { protocolColor = nativeWarning.opacity(0.90) }
            if upper.contains("DNS") { protocolColor = nativePositive.opacity(0.90) }
            if upper.contains("HTTP") { protocolColor = nativeAccent.opacity(0.90) }
        }

        if message.isEmpty {
            message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let source = localizedLogSourceLabel(log.source)
        let level = normalizedLogLevel(log.level)
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
