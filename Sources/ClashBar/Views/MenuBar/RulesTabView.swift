import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct RulesTabView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var proxyStore: ProxyStore
    @StateObject private var viewModel = RulesViewModel()
    @AppStorage("clashbar.rules.group_by_policy.v1") private var storedGroupByPolicy = false
    @State private var hoveredRuleKey: String?
    @State private var hoveredGroupPolicy: String?
    @State private var expandedPolicies: Set<String> = []

    var body: some View {
        let output = self.viewModel.output
        let visibleRules = output.rules
        let providerLookup = output.providerLookup

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: T.space8) {
                    self.rulesStatChip(title: self.tr("ui.rule.stats.rules"), value: "\(self.proxyStore.rulesCount)")
                    self.rulesStatChip(
                        title: self.tr("ui.rule.stats.sets"),
                        value: "\(self.proxyStore.providerRuleCount)")
                }

                Spacer(minLength: 0)
                HStack(spacing: T.space4) {
                    self.rulesGroupToggle
                    self.rulesRefreshButton
                }
            }
            .padding(.vertical, T.space6)
            .overlay(alignment: .bottom) { self.hairline }

            self.rulesControlCard
                .overlay(alignment: .bottom) { self.hairline }

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
            .overlay(alignment: .bottom) { self.hairline }

            if visibleRules.isEmpty {
                self.rulesEmptyState
            } else if self.viewModel.groupByPolicy {
                self.groupedRulesList(groups: output.groups, providerLookup: providerLookup)
            } else {
                self.flatRulesList(visibleRules: visibleRules, providerLookup: providerLookup)
            }
        }
        .onAppear {
            self.viewModel.groupByPolicy = self.storedGroupByPolicy
            self.refreshData()
        }
        .onChange(of: self.proxyStore.ruleItems) { _ in self.refreshData() }
        .onChange(of: self.proxyStore.ruleProviders) { _ in self.refreshData() }
        .onChange(of: self.viewModel.filterText) { _ in self.refreshData() }
        .onChange(of: self.viewModel.typeFilter) { _ in self.refreshData() }
        .onChange(of: self.viewModel.policyFilter) { _ in self.refreshData() }
        .onChange(of: self.viewModel.groupByPolicy) { _ in self.refreshData() }
    }

    private var hairline: some View {
        Rectangle()
            .fill(nativeSeparator)
            .frame(height: T.stroke)
    }

    private func refreshData() {
        self.viewModel.updateVisibleRules(
            items: self.proxyStore.ruleItems,
            providers: self.proxyStore.ruleProviders)
    }

    var rulesControlCard: some View {
        VStack(alignment: .leading, spacing: T.space4) {
            HStack(spacing: T.space4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: T.space4) {
                        ForEach(RulesTypeFilter.allCases) { filter in
                            self.ruleTypeChip(filter)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                self.fractionSummaryBadge(
                    current: self.viewModel.output.rules.count,
                    total: self.proxyStore.rulesCount)
            }

            HStack(spacing: T.space6) {
                TextField(self.tr("ui.placeholder.filter_rule"), text: self.$viewModel.filterText)
                    .textFieldStyle(.roundedBorder)
                    .font(.app(size: T.FontSize.body, weight: .regular))
                    .foregroundStyle(nativePrimaryLabel)

                self.rulesPolicyMenu
            }
        }
        .menuRowPadding(vertical: T.space4)
    }

    func ruleTypeChip(_ filter: RulesTypeFilter) -> some View {
        self.filterChip(
            title: self.tr(filter.titleKey),
            count: self.viewModel.output.typeCounts[filter] ?? 0,
            selected: self.viewModel.typeFilter == filter)
        {
            self.viewModel.typeFilter = filter
        }
    }

    var rulesPolicyMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.viewModel.policyFilter,
            options: self.viewModel.output.policyOptions,
            symbol: "arrow.triangle.branch",
            helpText: self.tr("ui.rules.filter.policy"),
            optionTitle: { $0.isAll ? self.tr("ui.rules.policy.all") : $0.name },
            onSelect: { self.viewModel.policyFilter = $0 }))
    }

    var rulesGroupToggle: some View {
        let grouped = self.viewModel.groupByPolicy
        return self.compactTopIcon(
            grouped ? "rectangle.3.group.fill" : "list.bullet",
            label: self.tr("ui.rules.group.toggle"),
            toneOverride: grouped ? nativeInfo : nil)
        {
            self.viewModel.groupByPolicy.toggle()
            self.storedGroupByPolicy = self.viewModel.groupByPolicy
        }
        .help(self.tr("ui.rules.group.toggle"))
    }

    var rulesEmptyState: some View {
        let key = self.proxyStore.ruleItems.isEmpty ? "ui.empty.rules" : "ui.empty.rules.no_match"
        return Text(self.tr(key))
            .font(.app(size: T.FontSize.body, weight: .regular))
            .foregroundStyle(nativeSecondaryLabel)
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
    }

    func flatRulesList(visibleRules: [RuleItem], providerLookup: [String: ProviderDetail]) -> some View {
        MeasurementAwareVStack(spacing: 0) {
            ForEach(Array(visibleRules.enumerated()), id: \.offset) { index, rule in
                self.rulesRow(rule: rule, rowKey: "\(index)", providerLookup: providerLookup)

                if index < visibleRules.count - 1 {
                    self.hairline
                }
            }
        }
    }

    func groupedRulesList(groups: [RuleGroup], providerLookup: [String: ProviderDetail]) -> some View {
        VStack(spacing: 0) {
            ForEach(groups) { group in
                self.policyGroupHeader(group)

                self.hairline

                if self.expandedPolicies.contains(group.policy) {
                    ForEach(Array(group.rules.enumerated()), id: \.offset) { index, rule in
                        self.rulesRow(
                            rule: rule,
                            rowKey: "\(group.policy)#\(index)",
                            providerLookup: providerLookup,
                            showsPolicy: false)

                        self.hairline
                    }
                }
            }
        }
    }

    func policyGroupHeader(_ group: RuleGroup) -> some View {
        let expanded = self.expandedPolicies.contains(group.policy)
        let hovered = self.hoveredGroupPolicy == group.policy
        let name = group.policy.trimmedNonEmpty ?? self.tr("ui.common.na")

        return Button {
            self.toggleGroup(group.policy)
        } label: {
            HStack(spacing: 0) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.app(size: T.FontSize.caption, weight: .bold))
                    .foregroundStyle(hovered ? nativePrimaryLabel : nativeSecondaryLabel)
                    .frame(width: 24, alignment: .leading)

                Text(name)
                    .font(.app(size: T.FontSize.body, weight: .semibold))
                    .foregroundStyle(nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: T.space4)

                Text("\(group.rules.count)")
                    .font(.app(size: T.FontSize.caption, weight: .bold))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, T.space6)
                    .padding(.vertical, T.space1)
                    .background(nativeBadgeCapsule())
            }
            .padding(.horizontal, T.space4)
            .frame(height: T.rowHeight)
            .background(nativeHoverRowBackground(hovered))
        }
        .buttonStyle(.plain)
        .onHover { self.hoveredGroupPolicy = self.nextHovered(
            current: self.hoveredGroupPolicy, target: group.policy, isHovering: $0) }
    }

    private func toggleGroup(_ policy: String) {
        if !self.expandedPolicies.insert(policy).inserted {
            self.expandedPolicies.remove(policy)
        }
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
            isLoading: self.proxyStore.isRuleProvidersRefreshing)
        {
            await self.appViewModel.refreshRuleProviders()
        }
        .help(self.tr("ui.action.refresh"))
        .opacity(self.proxyStore.isRuleProvidersRefreshing ? 0.6 : 1)
    }

    func rulesRow(
        rule: RuleItem,
        rowKey: String,
        providerLookup: [String: ProviderDetail],
        showsPolicy: Bool = true) -> some View
    {
        let hovered = self.hoveredRuleKey == rowKey
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
            .frame(width: showsPolicy ? 120 : 120 + 90 + T.space6, alignment: .leading)
            .padding(.trailing, T.space6)

            if showsPolicy {
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
            }

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
        .onHover { self.hoveredRuleKey = self.nextHovered(
            current: self.hoveredRuleKey, target: rowKey, isHovering: $0) }
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
