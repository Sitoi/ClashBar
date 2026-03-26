import AppKit
import SwiftUI

extension MenuBarRootView {
    private enum ConnectionsLayout {
        static let topLineSpacing: CGFloat = MenuBarLayoutTokens.space2
        static let topMetaSpacing: CGFloat = MenuBarLayoutTokens.space1
        static let secondLineSpacing: CGFloat = MenuBarLayoutTokens.space2
        static let rowLineHeight: CGFloat = 16
        static let topRuleMinWidth: CGFloat = 26
        static let topPayloadMinWidth: CGFloat = 14
        /// Width of the content VStack inside each connection row (static — panel is fixed 360pt)
        /// = panelWidth - panelContentHPad*2 - rowHPad*2 - leadingIcon - hstackGaps - closeButton
        /// = 360 - 16 - 8 - 16 - 12 - 12 = 296
        static let rowContentWidth: CGFloat =
            MenuBarLayoutTokens.panelWidth
                - (MenuBarLayoutTokens.space8 * 2) // panelContent horizontal padding
                - (MenuBarLayoutTokens.space4 * 2)
                - MenuBarLayoutTokens.rowLeadingIcon
                - (MenuBarLayoutTokens.space6 * 2)
                - 12
    }

    private static var textWidthCache: [String: CGFloat] = [:]

    var connectionsTabBody: some View {
        let connections = self.connectionsViewModel.visibleConnections

        return VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
            self.connectionsControlCard

            if connections.isEmpty {
                emptyCard(tr("ui.empty.connections"))
            } else {
                MeasurementAwareVStack(spacing: 0) {
                    SeparatedForEach(data: connections, id: \.id, separator: nativeSeparator) { conn in
                        self.connectionRow(conn)
                    }
                }
            }
        }
    }

    var connectionsControlCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.connectionsFilterMenu
                self.connectionsSortMenu

                Spacer(minLength: 0)

                self.fractionSummaryBadge(
                    current: self.connectionsViewModel.visibleConnections.count,
                    total: min(self.connectionsStore.connections.count, 120))

                self.compactTopIcon(
                    "xmark",
                    label: tr("ui.action.close_all"),
                    warning: true)
                {
                    await appSession.closeAllConnections()
                }
                .help(tr("ui.action.close_all"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField(tr("ui.placeholder.filter_connection"), text: $connectionsViewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    var connectionsFilterMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.transportFilter,
            options: ConnectionsTransportFilter.allCases,
            symbol: "line.3.horizontal.decrease.circle",
            helpText: tr("ui.network.filter.transport"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.transportFilter = $0 }))
    }

    var connectionsSortMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.sortOption,
            options: ConnectionsSortOption.allCases,
            symbol: "arrow.up.arrow.down",
            helpText: tr("ui.network.sort.label"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.sortOption = $0 }))
    }

    func refreshVisibleConnections() {
        self.connectionsViewModel.updateVisibleConnections(
            from: self.connectionsStore.connections,
            searchText: { connection in
                self.connectionSearchText(for: connection)
            })
    }

    func connectionRow(_ conn: ConnectionSummary) -> some View {
        let visual = self.connectionVisual(for: conn)
        let hovered = self.connectionsViewModel.hoveredConnectionID == conn.id
        let hostText = conn.metadata?.host.trimmedNonEmpty
            ?? conn.metadata?.destinationIP.trimmedNonEmpty
            ?? tr("ui.common.na")
        let networkType = conn.metadata?.network.trimmedNonEmpty?.uppercased() ?? "--"
        let timeText = self.connectionTimeOnly(conn.start)
        let upText = ValueFormatter.bytesCompactNoSpace(conn.upload ?? 0)
        let downText = ValueFormatter.bytesCompactNoSpace(conn.download ?? 0)
        let parsedRule = self.parseConnectionRule(conn.rule)
        let ruleTypeText = self.connectionRuleTypeText(conn.rule, fallback: parsedRule?.type)
        let rulePayloadText = conn.rulePayload.trimmedNonEmpty
            ?? parsedRule?.payload.trimmedNonEmpty
            ?? "--"

        return HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
            Image(systemName: visual.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(visual.color)
                .frame(
                    width: MenuBarLayoutTokens.rowLeadingIcon,
                    height: MenuBarLayoutTokens.rowLeadingIcon,
                    alignment: .center)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                self.connectionRowTopLine(host: hostText, ruleType: ruleTypeText, rulePayload: rulePayloadText)
                self.connectionRowMetrics(time: timeText, network: networkType, up: upText, down: downText)
                self.connectionsChainsLine(parts: self.connectionChainsParts(conn.chains))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            self.connectionRowCloseButton(id: conn.id, hovered: hovered)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space4)
        .padding(.vertical, MenuBarLayoutTokens.space2)
        .background(nativeHoverRowBackground(hovered))
        .onHover { self.connectionsViewModel.hoveredConnectionID = self.nextHovered(
            current: self.connectionsViewModel.hoveredConnectionID, target: conn.id, isHovering: $0) }
        .contextMenu { self.connectionRowContextMenu(conn) }
    }

    private func connectionRowTopLine(host: String, ruleType: String, rulePayload: String) -> some View {
        // Use static rowContentWidth constant — no GeometryReader needed since panel is always 360pt
        let layout = self.connectionsTopLineLayout(
            totalWidth: ConnectionsLayout.rowContentWidth,
            ruleText: ruleType,
            payloadText: rulePayload)

        return HStack(spacing: ConnectionsLayout.topLineSpacing) {
            Text(host)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: layout.hostWidth, alignment: .leading)

            HStack(spacing: ConnectionsLayout.topMetaSpacing) {
                self.connectionsTopBadge(text: ruleType)
                    .frame(width: layout.ruleWidth, alignment: .trailing)
                self.connectionsTopPayload(text: rulePayload)
                    .frame(width: layout.payloadWidth, alignment: .trailing)
            }
            .frame(
                width: layout.ruleWidth + ConnectionsLayout.topMetaSpacing + layout.payloadWidth,
                alignment: .trailing)
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private func connectionRowMetrics(time: String, network: String, up: String, down: String) -> some View {
        // Use static rowContentWidth — no GeometryReader needed since panel is always 360pt
        let columnWidth = max(
            (ConnectionsLayout.rowContentWidth - (ConnectionsLayout.secondLineSpacing * 3)) / 4,
            0)

        return HStack(spacing: ConnectionsLayout.secondLineSpacing) {
            self.connectionsMetricColumn(
                symbol: "clock",
                text: time,
                fallback: tr("ui.common.na"),
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "network",
                text: network,
                fallback: tr("ui.common.na"),
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "arrow.up",
                text: up,
                symbolColor: nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
            self.connectionsMetricColumn(
                symbol: "arrow.down",
                text: down,
                symbolColor: nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private func connectionRowCloseButton(id: String, hovered: Bool) -> some View {
        Button {
            Task { await appSession.closeConnection(id: id) }
        } label: {
            Image(systemName: "xmark")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hovered ? nativeSecondaryLabel : nativeTertiaryLabel)
        .frame(width: 12, height: 12)
        .opacity(hovered ? 1 : 0)
    }

    @ViewBuilder
    private func connectionRowContextMenu(_ conn: ConnectionSummary) -> some View {
        Button(role: .destructive) {
            Task { await appSession.closeConnection(id: conn.id) }
        } label: {
            Label(tr("ui.action.close_connection"), systemImage: "xmark.circle")
        }

        if let host = appSession.resolvedConnectionHost(for: conn) {
            Button {
                appSession.copyConnectionHost(host)
            } label: {
                Label(tr("ui.action.copy_host"), systemImage: "doc.on.doc")
            }
        }

        Button {
            appSession.copyConnectionID(conn.id)
        } label: {
            Label(tr("ui.action.copy_connection_id"), systemImage: "number")
        }
    }

    func connectionsMetricColumn(
        symbol: String,
        text: String,
        symbolColor: Color = .secondary,
        textColor: Color = .secondary,
        fallback: String? = nil,
        spacing: CGFloat = MenuBarLayoutTokens.space2,
        truncation: Text.TruncationMode = .middle,
        width: CGFloat) -> some View
    {
        let renderedText = text.isEmpty ? (fallback ?? "") : text

        return HStack(spacing: spacing) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 10, alignment: .leading)
            Text(renderedText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(truncation)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }

    func connectionsTopBadge(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .padding(.horizontal, MenuBarLayoutTokens.space2)
            .padding(.vertical, MenuBarLayoutTokens.space1)
            .background(nativeBadgeCapsule())
    }

    func connectionsTopPayload(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    func connectionsChainsLine(parts: [String]) -> some View {
        let chainText = parts.joined(separator: " > ")
        let displayText = parts.isEmpty ? tr("ui.common.na") : chainText

        return HStack(spacing: MenuBarLayoutTokens.space2) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)
                .frame(width: 10, alignment: .leading)

            Text(displayText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ConnectionsLayout.rowLineHeight, alignment: .leading)
    }

    func connectionsTopLineLayout(
        totalWidth: CGFloat,
        ruleText: String,
        payloadText: String) -> (hostWidth: CGFloat, ruleWidth: CGFloat, payloadWidth: CGFloat)
    {
        guard totalWidth > 0 else { return (0, 0, 0) }

        let hostMinWidth = floor(totalWidth * 0.5)
        let metaMaxWidth = max(totalWidth - ConnectionsLayout.topLineSpacing - hostMinWidth, 0)

        var ruleWidth = max(
            ConnectionsLayout.topRuleMinWidth,
            self
                .connectionsMonospacedTextWidth(
                    ruleText,
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: .semibold) +
                4)
        var payloadWidth = max(
            ConnectionsLayout.topPayloadMinWidth,
            self.connectionsMonospacedTextWidth(
                payloadText,
                size: MenuBarLayoutTokens.FontSize.caption,
                weight: .medium))
        let desiredMetaWidth = ruleWidth + ConnectionsLayout.topMetaSpacing + payloadWidth

        if desiredMetaWidth > metaMaxWidth {
            var overflow = desiredMetaWidth - metaMaxWidth

            let payloadReducible = max(payloadWidth - ConnectionsLayout.topPayloadMinWidth, 0)
            let payloadReduction = min(overflow, payloadReducible)
            payloadWidth -= payloadReduction
            overflow -= payloadReduction

            if overflow > 0 {
                let ruleReducible = max(ruleWidth - ConnectionsLayout.topRuleMinWidth, 0)
                let ruleReduction = min(overflow, ruleReducible)
                ruleWidth -= ruleReduction
                overflow -= ruleReduction
            }

            if overflow > 0 {
                let metaContentWidth = max(metaMaxWidth - ConnectionsLayout.topMetaSpacing, 0)
                if metaContentWidth <= 0 {
                    ruleWidth = 0
                    payloadWidth = 0
                } else {
                    let total = max(ruleWidth + payloadWidth, 1)
                    let ruleRatio = ruleWidth / total
                    ruleWidth = floor(metaContentWidth * ruleRatio)
                    payloadWidth = max(metaContentWidth - ruleWidth, 0)
                }
            }
        }

        let metaWidth = ruleWidth + ConnectionsLayout.topMetaSpacing + payloadWidth
        let hostWidth = max(totalWidth - ConnectionsLayout.topLineSpacing - metaWidth, hostMinWidth)
        return (hostWidth, ruleWidth, payloadWidth)
    }

    func connectionsMonospacedTextWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let cacheKey = "\(text)\0\(size)\0\(weight.rawValue)"
        if let cached = Self.textWidthCache[cacheKey] {
            return cached
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
        ]
        let width = ceil((text as NSString).size(withAttributes: attributes).width)
        Self.textWidthCache[cacheKey] = width
        return width
    }

    func connectionRuleTypeText(_ raw: String?, fallback: String?) -> String {
        let candidate = fallback.trimmedNonEmpty ?? raw.trimmedNonEmpty ?? ""
        guard !candidate.isEmpty else { return "--" }

        let normalized = candidate.uppercased()
        if normalized == "MATCH" || normalized == "FINAL" { return "--" }
        return candidate
    }

    func connectionChainsParts(_ chains: [String]?) -> [String] {
        Array((chains ?? []).compactMap(\.trimmedNonEmpty).reversed())
    }

    func parseConnectionRule(_ raw: String?) -> (type: String, payload: String?)? {
        guard let raw = raw.trimmedNonEmpty else {
            return nil
        }

        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let type = raw[..<open].trimmed
            let payload = raw[raw.index(after: open)..<close].trimmed
            if let type = type.nonEmpty {
                return (type, payload.nonEmpty)
            }
        }

        let commaParts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        if commaParts.count == 2 {
            let type = commaParts[0].trimmed
            let payload = commaParts[1].trimmed
            if let type = type.nonEmpty {
                return (type, payload.nonEmpty)
            }
        }

        return (raw, nil)
    }

    func connectionTimeOnly(_ input: String?) -> String {
        let full = ValueFormatter.dateTimeFromISO(input)
        guard full != "--" else { return full }
        return full.split(separator: " ").last.map(String.init) ?? full
    }

    func connectionVisual(for conn: ConnectionSummary) -> (symbol: String, color: Color) {
        let host = conn.metadata?.host?.lowercased() ?? ""
        let network = conn.metadata?.network?.lowercased() ?? ""

        if host.contains("google") || host.contains("gstatic") {
            return ("shield.fill", nativePurple.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("icloud") || host.contains("apple") {
            return ("icloud.fill", nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("github") {
            return ("terminal.fill", nativeIndigo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("twitter") || host.contains("x.com") {
            return ("lock.fill", nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("amazon") {
            return ("cart.fill", nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("udp") {
            return ("dot.radiowaves.left.and.right", nativeTeal.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("tcp") {
            return ("network", nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        return ("globe", nativeSecondaryLabel)
    }

    func connectionSearchText(for conn: ConnectionSummary) -> String {
        let host = conn.metadata?.host ?? ""
        let destinationIP = conn.metadata?.destinationIP ?? ""
        let sourceIP = conn.metadata?.sourceIP ?? ""
        let network = conn.metadata?.network ?? ""
        let id = conn.id
        let rule = conn.rule ?? ""
        let rulePayload = conn.rulePayload ?? ""
        let chains = self.connectionChainsParts(conn.chains).joined(separator: " > ")
        let start = conn.start ?? ""
        return "\(host) \(destinationIP) \(sourceIP) \(network) \(id) \(rule) \(rulePayload) \(chains) \(start)"
    }
}
