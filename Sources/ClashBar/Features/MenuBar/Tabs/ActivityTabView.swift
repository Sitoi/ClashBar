import AppKit
import SwiftUI

extension MenuBarRoot {
    private enum ActivityLayout {
        static let topLineSpacing: CGFloat = 2
        static let topMetaSpacing: CGFloat = 1
        static let secondLineSpacing: CGFloat = 2
        static let rowLineHeight: CGFloat = 15
        static let topRuleMinWidth: CGFloat = 26
        static let topPayloadMinWidth: CGFloat = 14
    }

    var activityTabBody: some View {
        let connections = self.filteredConnections

        return VStack(alignment: .leading, spacing: MenuBarLayoutTokens.sectionGap) {
            self.activityControlCard

            if connections.isEmpty {
                emptyCard(tr("ui.empty.connections"))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(connections.enumerated()), id: \.element.id) { index, conn in
                        self.connectionRow(conn)

                        if index < connections.count - 1 {
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

    var activityControlCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.vDense + 2) {
            HStack(spacing: MenuBarLayoutTokens.hDense) {
                Text(tr("ui.tab.activity"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(nativeTertiaryLabel)

                Spacer(minLength: 0)

                asyncBorderedIconButton(
                    symbol: "arrow.clockwise",
                    label: tr("ui.action.refresh"))
                {
                    await appState.refreshConnections()
                }

                asyncBorderedIconButton(
                    symbol: "xmark",
                    label: tr("ui.action.close_all"))
                {
                    await appState.closeAllConnections()
                }
            }

            TextField(tr("ui.placeholder.filter_connection"), text: $networkFilterText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.vDense + 2)
        .background(nativeSectionCard())
    }

    var filteredConnections: [ConnectionSummary] {
        let keyword = networkFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Array(appState.connections.prefix(120))
        guard !keyword.isEmpty else { return source }

        return source.filter { conn in
            self.connectionSearchText(for: conn).localizedStandardContains(keyword)
        }
    }

    func connectionRow(_ conn: ConnectionSummary) -> some View {
        let visual = self.connectionVisual(for: conn)
        let hovered = hoveredConnectionID == conn.id
        let host = conn.metadata?.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationIP = conn.metadata?.destinationIP?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostText = self.trimmedNonEmpty(host) ?? self.trimmedNonEmpty(destinationIP) ?? tr("ui.common.na")
        let networkType = self.trimmedNonEmpty(conn.metadata?.network)?.uppercased() ?? "--"
        let timeText = self.connectionTimeOnly(conn.start)
        let upText = ValueFormatter.bytesCompactNoSpace(conn.upload ?? 0)
        let downText = ValueFormatter.bytesCompactNoSpace(conn.download ?? 0)
        let parsedRule = self.parseConnectionRule(conn.rule)
        let ruleTypeText = self.connectionRuleTypeText(conn.rule, fallback: parsedRule?.type)
        let rulePayloadText = self.trimmedNonEmpty(conn.rulePayload) ?? self.trimmedNonEmpty(parsedRule?.payload) ?? "--"
        let chainParts = self.connectionChainsParts(conn.chains)

        return HStack(spacing: MenuBarLayoutTokens.hDense) {
            Image(systemName: visual.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(visual.color)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.vDense) {
                GeometryReader { proxy in
                    let layout = self.activityTopLineLayout(
                        totalWidth: max(proxy.size.width, 0),
                        ruleText: ruleTypeText,
                        payloadText: rulePayloadText)

                    HStack(spacing: ActivityLayout.topLineSpacing) {
                        Text(hostText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(nativePrimaryLabel)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: layout.hostWidth, alignment: .leading)

                        HStack(spacing: ActivityLayout.topMetaSpacing) {
                            self.activityTopBadge(text: ruleTypeText)
                                .frame(width: layout.ruleWidth, alignment: .trailing)
                            self.activityTopPayload(text: rulePayloadText)
                                .frame(width: layout.payloadWidth, alignment: .trailing)
                        }
                        .frame(
                            width: layout.ruleWidth + ActivityLayout.topMetaSpacing + layout.payloadWidth,
                            alignment: .trailing)
                    }
                }
                .frame(height: ActivityLayout.rowLineHeight)

                GeometryReader { proxy in
                    let totalWidth = max(proxy.size.width, 0)
                    let columnWidth = max((totalWidth - (ActivityLayout.secondLineSpacing * 3)) / 4, 0)

                    HStack(spacing: ActivityLayout.secondLineSpacing) {
                        self.activityMetricColumn(
                            symbol: "clock",
                            text: timeText,
                            fallback: tr("ui.common.na"),
                            width: columnWidth)

                        self.activityMetricColumn(
                            symbol: "network",
                            text: networkType,
                            fallback: tr("ui.common.na"),
                            width: columnWidth)

                        self.activityMetricColumn(
                            symbol: "arrow.up",
                            text: upText,
                            symbolColor: nativeInfo.opacity(0.9),
                            spacing: 0,
                            truncation: .tail,
                            width: columnWidth)

                        self.activityMetricColumn(
                            symbol: "arrow.down",
                            text: downText,
                            symbolColor: nativePositive.opacity(0.9),
                            spacing: 0,
                            truncation: .tail,
                            width: columnWidth)
                    }
                }
                .frame(height: ActivityLayout.rowLineHeight)

                self.activityChainsLine(parts: chainParts)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await appState.closeConnection(id: conn.id) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovered ? nativeSecondaryLabel : nativeTertiaryLabel)
            .frame(width: 12, height: 12)
            .opacity(hovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.14), value: hovered)
        }
        .padding(.horizontal, MenuBarLayoutTokens.hRow)
        .padding(.vertical, MenuBarLayoutTokens.vDense + 1)
        .background(nativeHoverRowBackground(hovered))
        .onHover { isHovering in
            hoveredConnectionID = isHovering ? conn.id : (hoveredConnectionID == conn.id ? nil : hoveredConnectionID)
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await appState.closeConnection(id: conn.id) }
            } label: {
                Label(tr("ui.action.close_connection"), systemImage: "xmark.circle")
            }

            if let host = appState.resolvedConnectionHost(for: conn) {
                Button {
                    appState.copyConnectionHost(host)
                } label: {
                    Label(tr("ui.action.copy_host"), systemImage: "doc.on.doc")
                }
            }

            Button {
                appState.copyConnectionID(conn.id)
            } label: {
                Label(tr("ui.action.copy_connection_id"), systemImage: "number")
            }
        }
    }

    func activityMetricColumn(
        symbol: String,
        text: String,
        symbolColor: Color = .secondary,
        textColor: Color = .secondary,
        fallback: String? = nil,
        spacing: CGFloat = 2,
        truncation: Text.TruncationMode = .middle,
        width: CGFloat) -> some View
    {
        let renderedText = text.isEmpty ? (fallback ?? "") : text

        return HStack(spacing: spacing) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 10, alignment: .leading)
            Text(renderedText)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(truncation)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }

    func activityTopBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(nativeBadgeCapsule())
    }

    func activityTopPayload(text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    func activityChainsLine(parts: [String]) -> some View {
        let chainText = parts.joined(separator: " > ")
        let displayText = parts.isEmpty ? tr("ui.common.na") : chainText

        return HStack(spacing: 2) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(nativeSecondaryLabel)
                .frame(width: 10, alignment: .leading)

            Text(displayText)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ActivityLayout.rowLineHeight, alignment: .leading)
    }

    func activityTopLineLayout(
        totalWidth: CGFloat,
        ruleText: String,
        payloadText: String) -> (hostWidth: CGFloat, ruleWidth: CGFloat, payloadWidth: CGFloat)
    {
        guard totalWidth > 0 else { return (0, 0, 0) }

        let hostMinWidth = floor(totalWidth * 0.5)
        let metaMaxWidth = max(totalWidth - ActivityLayout.topLineSpacing - hostMinWidth, 0)

        var ruleWidth = max(
            ActivityLayout.topRuleMinWidth,
            self.activityMonospacedTextWidth(ruleText, size: 9, weight: .semibold) + 4)
        var payloadWidth = max(
            ActivityLayout.topPayloadMinWidth,
            self.activityMonospacedTextWidth(payloadText, size: 9, weight: .medium))
        let desiredMetaWidth = ruleWidth + ActivityLayout.topMetaSpacing + payloadWidth

        if desiredMetaWidth > metaMaxWidth {
            var overflow = desiredMetaWidth - metaMaxWidth

            let payloadReducible = max(payloadWidth - ActivityLayout.topPayloadMinWidth, 0)
            let payloadReduction = min(overflow, payloadReducible)
            payloadWidth -= payloadReduction
            overflow -= payloadReduction

            if overflow > 0 {
                let ruleReducible = max(ruleWidth - ActivityLayout.topRuleMinWidth, 0)
                let ruleReduction = min(overflow, ruleReducible)
                ruleWidth -= ruleReduction
                overflow -= ruleReduction
            }

            if overflow > 0 {
                let metaContentWidth = max(metaMaxWidth - ActivityLayout.topMetaSpacing, 0)
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

        let metaWidth = ruleWidth + ActivityLayout.topMetaSpacing + payloadWidth
        let hostWidth = max(totalWidth - ActivityLayout.topLineSpacing - metaWidth, hostMinWidth)
        return (hostWidth, ruleWidth, payloadWidth)
    }

    func activityMonospacedTextWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
        ]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    func connectionRuleTypeText(_ raw: String?, fallback: String?) -> String {
        let candidate = self.trimmedNonEmpty(fallback) ?? self.trimmedNonEmpty(raw) ?? ""
        guard !candidate.isEmpty else { return "--" }

        let normalized = candidate.uppercased()
        if normalized == "MATCH" || normalized == "FINAL" { return "--" }
        return candidate
    }

    func connectionChainsParts(_ chains: [String]?) -> [String] {
        Array((chains ?? []).compactMap(self.trimmedNonEmpty).reversed())
    }

    func parseConnectionRule(_ raw: String?) -> (type: String, payload: String?)? {
        guard let raw = trimmedNonEmpty(raw) else {
            return nil
        }

        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let type = raw[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = raw[raw.index(after: open)..<close].trimmingCharacters(in: .whitespacesAndNewlines)
            if !type.isEmpty {
                return (String(type), payload.isEmpty ? nil : String(payload))
            }
        }

        let commaParts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        if commaParts.count == 2 {
            let type = commaParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = commaParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !type.isEmpty {
                return (String(type), payload.isEmpty ? nil : String(payload))
            }
        }

        return (raw, nil)
    }

    func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func connectionTimeOnly(_ input: String?) -> String {
        let full = ValueFormatter.dateTimeFromISO(input)
        guard full != "--" else { return full }
        return full.split(separator: " ").last.map(String.init) ?? full
    }

    func connectionVisual(for conn: ConnectionSummary) -> (symbol: String, color: Color) {
        let host = conn.metadata?.host?.lowercased() ?? ""
        let network = conn.metadata?.network?.lowercased() ?? ""
        let symbol = if host.contains("google") || host.contains("gstatic") {
            "shield.fill"
        } else if host.contains("icloud") || host.contains("apple") {
            "icloud.fill"
        } else if host.contains("github") {
            "terminal.fill"
        } else if host.contains("twitter") || host.contains("x.com") {
            "lock.fill"
        } else if host.contains("amazon") {
            "cart.fill"
        } else if network.contains("udp") {
            "dot.radiowaves.left.and.right"
        } else if network.contains("tcp") {
            "network"
        } else {
            "globe"
        }

        let iconColor: Color = switch symbol {
        case "shield.fill":
            nativePurple.opacity(0.92)
        case "icloud.fill":
            nativeInfo.opacity(0.92)
        case "terminal.fill":
            nativeIndigo.opacity(0.9)
        case "lock.fill":
            nativePositive.opacity(0.92)
        case "cart.fill":
            nativeWarning.opacity(0.92)
        case "dot.radiowaves.left.and.right":
            nativeTeal.opacity(0.92)
        case "network":
            nativeInfo.opacity(0.92)
        default:
            nativeSecondaryLabel
        }
        return (symbol, iconColor)
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
