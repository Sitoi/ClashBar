import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    private enum InsightsLayout {
        static let metricsSpacing: CGFloat = MenuBarLayoutTokens.space2
        static let metricsLineHeight: CGFloat = 16
        static let rowContentWidth: CGFloat =
            MenuBarLayoutTokens.panelWidth
                - (MenuBarLayoutTokens.space8 * 2)
                - (MenuBarLayoutTokens.space4 * 2)
                - MenuBarLayoutTokens.rowLeadingIcon
                - (MenuBarLayoutTokens.space6 * 2)
    }

    struct TopInsightEntry: Identifiable {
        let primary: String
        let secondary: String
        let value: String
        let share: Double

        var id: String {
            "\(self.primary)|\(self.secondary)|\(self.value)"
        }
    }

    var insightsTabBody: some View {
        let snapshot = self.trafficInsightsStore.snapshot(
            for: self.insightsTimeWindow,
            now: self.trafficInsightsStore.displayReferenceDate)

        return VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
            self.insightsControlsCard
            self.insightsOverviewCard(snapshot)

            switch self.insightsViewMode {
            case .overview:
                self.insightsOverviewSections(snapshot)
            case .domains:
                self.insightsDomainList(snapshot)
            case .rules:
                self.insightsRuleList(snapshot)
            case .routes:
                self.insightsRouteList(snapshot)
            }
        }
    }

    var insightsControlsCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                Text(tr("ui.tab.insights"))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(nativeTertiaryLabel)

                Spacer(minLength: 0)

                self.compactTopIcon(
                    "trash",
                    label: tr("ui.insights.reset_runtime"),
                    warning: true)
                {
                    self.trafficInsightsStore.resetAllStatistics()
                }
                .help(tr("ui.insights.reset_runtime"))
            }

            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.compactSelectionMenu(.init(
                    selection: self.insightsViewMode,
                    options: InsightsViewMode.allCases,
                    symbol: "rectangle.grid.1x2",
                    helpText: tr("ui.tab.insights"),
                    optionTitle: { self.tr($0.titleKey) },
                    onSelect: { self.insightsViewMode = $0 }))

                self.compactSelectionMenu(.init(
                    selection: self.insightsTimeWindow,
                    options: InsightsTimeWindow.allCases,
                    symbol: "clock.arrow.circlepath",
                    helpText: tr("ui.insights.window.summary", tr(self.insightsTimeWindow.titleKey)),
                    optionTitle: { self.tr($0.titleKey) },
                    onSelect: { self.insightsTimeWindow = $0 }))

                Spacer(minLength: 0)
            }

            HStack(spacing: MenuBarLayoutTokens.space6) {
                TextField(tr("ui.placeholder.search_insights"), text: self.$insightsSearchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
            }
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    func insightsOverviewCard(_ snapshot: TrafficInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            Text(tr("ui.insights.window.summary", tr(self.insightsTimeWindow.titleKey)))
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MenuBarLayoutTokens.space4) {
                self.insightMetricCard(title: tr("ui.insights.metric.total"), value: ValueFormatter.bytesInteger(snapshot.totalBytes), tint: nativeAccent)
                self.insightMetricCard(title: tr("ui.insights.metric.domains"), value: "\(snapshot.domainItems.count)", tint: nativeIndigo)
                self.insightMetricCard(title: tr("ui.insights.metric.upload"), value: ValueFormatter.bytesInteger(snapshot.totalUpload), tint: nativeInfo)
                self.insightMetricCard(title: tr("ui.insights.metric.download"), value: ValueFormatter.bytesInteger(snapshot.totalDownload), tint: nativePositive)
            }

            if self.insightsViewMode == .overview {
                TrafficSparklineView(
                    upValues: snapshot.trendPoints.map(\.upload),
                    downValues: snapshot.trendPoints.map(\.download))
                .frame(height: 56)
                .padding(.horizontal, MenuBarLayoutTokens.space2)
            }
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    @ViewBuilder
    func insightsOverviewSections(_ snapshot: TrafficInsightsSnapshot) -> some View {
        let domainRows = self.filteredInsightDomains(snapshot)
        let routeRows = self.filteredInsightRoutes(snapshot)

        if snapshot.totalBytes == 0 {
            emptyCard(tr("ui.empty.insights"))
        } else if domainRows.isEmpty && routeRows.isEmpty {
            emptyCard(tr("ui.empty.insights_attribution"))
        } else {
            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
                self.insightTopSection(
                    title: tr("ui.insights.top.domains"),
                    rows: domainRows.prefix(3).map { row in
                        TopInsightEntry(
                            primary: row.domain,
                            secondary: row.topRoute,
                            value: ValueFormatter.bytesInteger(row.total),
                            share: self.insightShare(total: row.total, overall: snapshot.totalBytes))
                    })

                self.insightTopSection(
                    title: tr("ui.insights.top.routes"),
                    rows: routeRows.prefix(3).map { row in
                        TopInsightEntry(
                            primary: row.route,
                            secondary: row.topDomain,
                            value: ValueFormatter.bytesInteger(row.total),
                            share: self.insightShare(total: row.total, overall: snapshot.totalBytes))
                    })
            }
        }
    }

    @ViewBuilder
    func insightsDomainList(_ snapshot: TrafficInsightsSnapshot) -> some View {
        let rows = self.filteredInsightDomains(snapshot)
        if rows.isEmpty {
            emptyCard(tr(snapshot.totalBytes > 0 ? "ui.empty.insights_attribution" : "ui.empty.insights"))
        } else {
            MeasurementAwareVStack(spacing: 0) {
                SeparatedForEach(data: rows, id: \.id, separator: nativeSeparator) { row in
                    self.insightDomainRow(row, totalBytes: snapshot.totalBytes)
                }
            }
        }
    }

    @ViewBuilder
    func insightsRuleList(_ snapshot: TrafficInsightsSnapshot) -> some View {
        let rows = self.filteredInsightRules(snapshot)
        if rows.isEmpty {
            emptyCard(tr(snapshot.totalBytes > 0 ? "ui.empty.insights_attribution" : "ui.empty.insights"))
        } else {
            MeasurementAwareVStack(spacing: 0) {
                SeparatedForEach(data: rows, id: \.id, separator: nativeSeparator) { row in
                    self.insightRuleRow(row, totalBytes: snapshot.totalBytes)
                }
            }
        }
    }

    @ViewBuilder
    func insightsRouteList(_ snapshot: TrafficInsightsSnapshot) -> some View {
        let rows = self.filteredInsightRoutes(snapshot)
        if rows.isEmpty {
            emptyCard(tr(snapshot.totalBytes > 0 ? "ui.empty.insights_attribution" : "ui.empty.insights"))
        } else {
            MeasurementAwareVStack(spacing: 0) {
                SeparatedForEach(data: rows, id: \.id, separator: nativeSeparator) { row in
                    self.insightRouteRow(row, totalBytes: snapshot.totalBytes)
                }
            }
        }
    }

    func filteredInsightDomains(_ snapshot: TrafficInsightsSnapshot) -> [TrafficInsightsDomainItem] {
        self.sortedInsightDomains(
            snapshot.domainItems.filter { row in
                self.insightSearchMatches([row.domain, row.topRule, row.topRoute])
            })
    }

    func filteredInsightRules(_ snapshot: TrafficInsightsSnapshot) -> [TrafficInsightsRuleItem] {
        self.sortedInsightRules(
            snapshot.ruleItems.filter { row in
                self.insightSearchMatches([row.rule, row.topDomain, row.topRoute])
            })
    }

    func filteredInsightRoutes(_ snapshot: TrafficInsightsSnapshot) -> [TrafficInsightsRouteItem] {
        self.sortedInsightRoutes(
            snapshot.routeItems.filter { row in
                self.insightSearchMatches([row.route, row.topDomain, row.topRule])
            })
    }

    func sortedInsightDomains(_ items: [TrafficInsightsDomainItem]) -> [TrafficInsightsDomainItem] {
        items.sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            if lhs.lastSeenAt != rhs.lastSeenAt { return lhs.lastSeenAt > rhs.lastSeenAt }
            return lhs.domain.localizedStandardCompare(rhs.domain) == .orderedAscending
        }
    }

    func sortedInsightRules(_ items: [TrafficInsightsRuleItem]) -> [TrafficInsightsRuleItem] {
        items.sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            if lhs.lastSeenAt != rhs.lastSeenAt { return lhs.lastSeenAt > rhs.lastSeenAt }
            return lhs.rule.localizedStandardCompare(rhs.rule) == .orderedAscending
        }
    }

    func sortedInsightRoutes(_ items: [TrafficInsightsRouteItem]) -> [TrafficInsightsRouteItem] {
        items.sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            if lhs.lastSeenAt != rhs.lastSeenAt { return lhs.lastSeenAt > rhs.lastSeenAt }
            return lhs.route.localizedStandardCompare(rhs.route) == .orderedAscending
        }
    }

    func insightSearchMatches(_ values: [String]) -> Bool {
        let keyword = self.insightsSearchText.trimmed
        guard !keyword.isEmpty else { return true }
        return values.joined(separator: " ").localizedStandardContains(keyword)
    }

    func insightDomainRow(_ row: TrafficInsightsDomainItem, totalBytes: Int64) -> some View {
        let ruleMeta = self.insightRuleMeta(row.topRule)
        return self.insightRowContainer(
            symbol: "globe",
            tint: nativeAccent.opacity(T.Opacity.solid),
            title: row.domain,
            total: row.total,
            totalBytes: totalBytes,
            topBadge: ruleMeta.type,
            topPayload: ruleMeta.payload,
            timeText: self.insightRelativeTime(row.lastSeenAt),
            centerText: ValueFormatter.bytesCompactNoSpace(row.total),
            uploadText: ValueFormatter.bytesCompactNoSpace(row.upload),
            downloadText: ValueFormatter.bytesCompactNoSpace(row.download),
            supportText: row.topRoute)
    }

    func insightRuleRow(_ row: TrafficInsightsRuleItem, totalBytes: Int64) -> some View {
        let ruleMeta = self.insightRuleMeta(row.rule)
        let supportText = "\(tr("ui.insights.view.domains")) \(row.topDomain) · \(tr("ui.insights.view.routes")) \(row.topRoute)"
        return self.insightRowContainer(
            symbol: "line.3.horizontal.decrease.circle",
            tint: nativeIndigo.opacity(T.Opacity.solid),
            title: ruleMeta.title,
            total: row.total,
            totalBytes: totalBytes,
            topBadge: ruleMeta.type,
            topPayload: ruleMeta.payload,
            timeText: self.insightRelativeTime(row.lastSeenAt),
            centerText: ValueFormatter.bytesCompactNoSpace(row.total),
            uploadText: ValueFormatter.bytesCompactNoSpace(row.upload),
            downloadText: ValueFormatter.bytesCompactNoSpace(row.download),
            supportText: supportText)
    }

    func insightRouteRow(_ row: TrafficInsightsRouteItem, totalBytes: Int64) -> some View {
        let ruleMeta = self.insightRuleMeta(row.topRule)
        let supportText = "\(tr("ui.insights.view.domains")) \(row.topDomain) · \(tr("ui.insights.view.rules")) \(row.topRule)"
        return self.insightRowContainer(
            symbol: "point.3.connected.trianglepath.dotted",
            tint: nativePositive.opacity(T.Opacity.solid),
            title: row.route,
            total: row.total,
            totalBytes: totalBytes,
            topBadge: ruleMeta.type,
            topPayload: ruleMeta.payload,
            timeText: self.insightRelativeTime(row.lastSeenAt),
            centerText: ValueFormatter.bytesCompactNoSpace(row.total),
            uploadText: ValueFormatter.bytesCompactNoSpace(row.upload),
            downloadText: ValueFormatter.bytesCompactNoSpace(row.download),
            supportText: supportText)
    }

    func insightRowContainer(
        symbol: String,
        tint: Color,
        title: String,
        total: Int64,
        totalBytes: Int64,
        topBadge: String,
        topPayload: String,
        timeText: String,
        centerText: String,
        uploadText: String,
        downloadText: String,
        supportText: String)
        -> some View
    {
        HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(tint)
                .frame(
                    width: MenuBarLayoutTokens.rowLeadingIcon,
                    height: MenuBarLayoutTokens.rowLeadingIcon,
                    alignment: .center)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                self.insightTopLine(
                    host: title,
                    ruleType: topBadge,
                    rulePayload: topPayload)

                self.insightMetricsLine(
                    leading: timeText,
                    center: centerText,
                    uploadText: uploadText,
                    downloadText: downloadText)

                self.insightSupportLine(supportText)

                GeometryReader { geometry in
                    let share = self.insightShare(total: total, overall: totalBytes)
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(nativeBadgeFill)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(tint.opacity(MenuBarLayoutTokens.Opacity.solid))
                                .frame(width: geometry.size.width * share)
                        }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space4)
        .padding(.vertical, MenuBarLayoutTokens.space2)
    }

    func insightMetricsLine(
        leading: String,
        center: String,
        uploadText: String,
        downloadText: String)
        -> some View
    {
        let columnWidth = max((InsightsLayout.rowContentWidth - (InsightsLayout.metricsSpacing * 3)) / 4, 0)

        return HStack(spacing: InsightsLayout.metricsSpacing) {
            self.connectionsMetricColumn(
                symbol: "clock",
                text: leading,
                fallback: tr("ui.common.unknown"),
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "sum",
                text: center,
                fallback: tr("ui.common.unknown"),
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "arrow.up",
                text: uploadText,
                symbolColor: nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "arrow.down",
                text: downloadText,
                symbolColor: nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
        }
        .frame(height: InsightsLayout.metricsLineHeight)
    }

    func insightTopLine(host: String, ruleType: String, rulePayload: String) -> some View {
        let layout = self.connectionsTopLineLayout(
            totalWidth: InsightsLayout.rowContentWidth,
            ruleText: ruleType,
            payloadText: rulePayload)

        return HStack(spacing: MenuBarLayoutTokens.space2) {
            Text(host)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: layout.hostWidth, alignment: .leading)

            HStack(spacing: MenuBarLayoutTokens.space1) {
                self.connectionsTopBadge(text: ruleType)
                    .frame(width: layout.ruleWidth, alignment: .trailing)
                self.connectionsTopPayload(text: rulePayload)
                    .frame(width: layout.payloadWidth, alignment: .trailing)
            }
            .frame(
                width: layout.ruleWidth + MenuBarLayoutTokens.space1 + layout.payloadWidth,
                alignment: .trailing)
        }
        .frame(height: InsightsLayout.metricsLineHeight)
    }

    func insightSupportLine(_ text: String) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space2) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)
                .frame(width: 10, alignment: .leading)

            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 16, alignment: .leading)
    }

    func insightMetricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
            Text(title)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)
            Text(value)
                .font(.app(size: MenuBarLayoutTokens.FontSize.subhead, weight: .bold))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space4)
        .background(
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                .fill(nativeControlFill.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .stroke(tint.opacity(0.25), lineWidth: MenuBarLayoutTokens.stroke)
                })
    }

    func insightTopSection(title: String, rows: [TopInsightEntry]) -> some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            Text(title)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)
            ForEach(rows) { row in
                self.topInsightRow(
                    primary: row.primary,
                    secondary: row.secondary,
                    value: row.value,
                    share: row.share)
            }
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    func topInsightRow(primary: String, secondary: String, value: String, share: Double) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space6) {
            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space1) {
                Text(primary)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                    .foregroundStyle(nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(secondary)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeSecondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: MenuBarLayoutTokens.space1) {
                Text(value)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                    .foregroundStyle(nativeSecondaryLabel)
                Text("\(Int((share * 100).rounded()))%")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
            }
        }
    }

    func insightShare(total: Int64, overall: Int64) -> Double {
        guard overall > 0 else { return 0 }
        return min(1, max(0, Double(total) / Double(overall)))
    }

    func insightRelativeTime(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return tr("ui.common.unknown") }
        return ValueFormatter.relativeTime(from: Date(timeIntervalSince1970: timestamp), language: self.language)
    }

    func insightRuleMeta(_ text: String) -> (title: String, type: String, payload: String) {
        let trimmed = text.trimmedNonEmpty ?? tr("ui.common.unknown")

        if let separator = trimmed.firstIndex(of: ":") {
            let type = String(trimmed[..<separator]).trimmedNonEmpty ?? "--"
            let payload = String(trimmed[trimmed.index(after: separator)...]).trimmedNonEmpty ?? "--"
            return (payload, self.connectionRuleTypeText(type, fallback: type), payload)
        }

        if let parsed = self.parseConnectionRule(trimmed) {
            let type = self.connectionRuleTypeText(parsed.type, fallback: parsed.type)
            let payload = parsed.payload?.trimmedNonEmpty ?? "--"
            let title = parsed.payload?.trimmedNonEmpty ?? parsed.type
            return (title, type, payload)
        }

        return (trimmed, self.connectionRuleTypeText(trimmed, fallback: trimmed), "--")
    }
}
