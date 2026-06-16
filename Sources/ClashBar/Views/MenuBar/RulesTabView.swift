import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct RulesTabView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = RulesViewModel()
    @State private var hoveredRuleIndex: Int?

    var body: some View {
        let visibleRules = self.viewModel.visibleRules
        let providerLookup = self.viewModel.providerLookup

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: T.space8) {
                    self.rulesStatChip(title: self.tr("ui.rule.stats.rules"), value: "\(self.appViewModel.rulesCount)")
                    self.rulesStatChip(
                        title: self.tr("ui.rule.stats.sets"),
                        value: "\(self.appViewModel.providerRuleCount)")
                }

                Spacer(minLength: 0)
                self.rulesRefreshButton
            }
            .padding(.vertical, T.space6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(nativeSeparator)
                    .frame(height: T.stroke)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 24)
                Text(self.tr("ui.rules.column.target_type"))
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .frame(width: 120, alignment: .leading)
                    .padding(.trailing, T.space6)
                Text(self.tr("ui.rules.column.policy"))
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .padding(.leading, T.space6)
                    .frame(width: 90, alignment: .leading)
                Text(self.tr("ui.rules.column.stats"))
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .textCase(.uppercase)
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(nativeSeparator)
                    .frame(height: T.stroke)
            }

            if visibleRules.isEmpty {
                Text(self.tr("ui.empty.rules"))
                    .font(.app(size: T.FontSize.body, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, T.space4)
                    .padding(.vertical, T.space8)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleRules.enumerated()), id: \.offset) { index, rule in
                        self.rulesRow(rule: rule, index: index, providerLookup: providerLookup)

                        if index < visibleRules.count - 1 {
                            Rectangle()
                                .fill(nativeSeparator)
                                .frame(height: T.stroke)
                        }
                    }
                }
            }
        }
        .onAppear { self.refreshData() }
        .onChange(of: self.appViewModel.ruleItems) { _ in self.refreshData() }
        .onChange(of: self.appViewModel.ruleProviders) { _ in self.refreshData() }
    }

    private func refreshData() {
        self.viewModel.updateVisibleRules(
            items: self.appViewModel.ruleItems,
            providers: self.appViewModel.ruleProviders)
    }

    func rulesStatChip(title: String, value: String) -> some View {
        HStack(spacing: T.space4) {
            Text(title.uppercased())
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
            Text(value)
                .font(.app(size: T.FontSize.body, weight: .bold))
                .foregroundStyle(nativePrimaryLabel)
        }
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space2)
    }

    var rulesRefreshButton: some View {
        self.compactTopIcon(
            "arrow.clockwise",
            label: self.tr("ui.action.refresh"),
            toneOverride: nativeInfo,
            isLoading: self.appViewModel.isRuleProvidersRefreshing)
        {
            await self.appViewModel.refreshRuleProviders()
        }
        .help(self.tr("ui.action.refresh"))
        .opacity(self.appViewModel.isRuleProvidersRefreshing ? 0.6 : 1)
    }

    func rulesRow(rule: RuleItem, index: Int, providerLookup: [String: ProviderDetail]) -> some View {
        let hovered = self.hoveredRuleIndex == index
        let typeText = (rule.type.trimmedNonEmpty ?? self.tr("ui.common.na")).uppercased()
        let targetText = rule.payload.trimmedNonEmpty ?? self.tr("ui.common.na")
        let policyText = rule.proxy.trimmedNonEmpty ?? self.tr("ui.common.na")
        let iconSpec = self.ruleTypeIcon(for: typeText)
        let badge = self.rulePolicyBadge(for: policyText)
        let stats = self.ruleStats(payload: targetText, providerLookup: providerLookup)

        return HStack(spacing: 0) {
            Image(systemName: iconSpec.symbol)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(iconSpec.color)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: T.space1) {
                Text(targetText)
                    .font(.app(size: T.FontSize.body, weight: .medium))
                    .foregroundStyle(nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(typeText)
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativeTertiaryLabel)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            .padding(.trailing, T.space6)

            HStack(spacing: T.space1) {
                if let symbol = badge.symbol {
                    Image(systemName: symbol)
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(badge.color)
                }
                Text(policyText)
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .foregroundStyle(badge.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 90, alignment: .leading)

            VStack(alignment: .trailing, spacing: T.space1) {
                Text("\(stats.count)")
                    .font(.app(size: T.FontSize.body, weight: .regular))
                    .foregroundStyle(stats.hasProvider ? nativeSecondaryLabel : nativeTertiaryLabel)
                if let updatedText = stats.updatedText {
                    Text(updatedText)
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeTertiaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, T.space4)
        .frame(height: T.rowHeight)
        .background(nativeHoverRowBackground(hovered))
        .onHover { self.hoveredRuleIndex = self.nextHovered(
            current: self.hoveredRuleIndex, target: index, isHovering: $0) }
    }

    func ruleTypeIcon(for type: String) -> (symbol: String, color: Color) {
        let lower = type.lowercased()
        if lower.contains("ipcidr") {
            return ("globe.americas.fill", nativeInfo.opacity(T.Opacity.solid))
        }
        if lower.contains("domain") || lower.contains("suffix") || lower.contains("keyword") {
            return ("network", nativeTeal.opacity(T.Opacity.solid))
        }
        if lower.contains("ruleset") {
            return ("list.bullet.rectangle.fill", nativeWarning.opacity(T.Opacity.solid))
        }
        return ("circle.grid.2x2.fill", nativeIndigo.opacity(T.Opacity.solid))
    }

    func rulePolicyBadge(for policy: String) -> (symbol: String?, color: Color) {
        let lower = policy.lowercased()
        if lower.contains("fishy") {
            return (
                symbol: "exclamationmark.triangle.fill",
                color: nativeAccent.opacity(T.Opacity.solid))
        }
        return (
            symbol: nil,
            color: nativeSecondaryLabel)
    }

    func ruleStats(
        payload: String,
        providerLookup: [String: ProviderDetail]) -> (count: Int, updatedText: String?, hasProvider: Bool)
    {
        let payloadTrimmed = payload.trimmed
        guard !payloadTrimmed.isEmpty, payloadTrimmed != self.tr("ui.common.na") else {
            return (count: 0, updatedText: nil, hasProvider: false)
        }

        if let provider = providerLookup[payloadTrimmed.lowercased()] {
            let count = max(0, provider.ruleCount ?? 0)
            return (
                count: count,
                updatedText: ValueFormatter.relativeTime(from: provider.updatedAt, language: self.language),
                hasProvider: true)
        }
        return (count: 0, updatedText: nil, hasProvider: false)
    }
}
