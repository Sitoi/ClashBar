import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct SeparatedForEach<Element: Equatable, ID: Hashable, RowContent: View>: View {
    private struct Item: Identifiable {
        let id: ID
        let element: Element
        let isLast: Bool
    }

    private let items: [Item]
    private let separator: Color
    private let content: (Element) -> RowContent

    init<Data: RandomAccessCollection>(
        data: Data,
        id idPath: KeyPath<Element, ID>,
        separator: Color,
        @ViewBuilder content: @escaping (Element) -> RowContent) where Data.Element == Element
    {
        let array = Array(data)
        self.items = array.enumerated().map { index, el in
            Item(id: el[keyPath: idPath], element: el, isLast: index == array.count - 1)
        }
        self.separator = separator
        self.content = content
    }

    var body: some View {
        ForEach(self.items) { item in
            self.content(item.element)
            if !item.isLast {
                Rectangle()
                    .fill(self.separator)
                    .frame(height: T.stroke)
            }
        }
    }
}

struct MeasurementAwareVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVStack(alignment: self.alignment, spacing: self.spacing) { self.content }
    }
}

struct CompactSelectionMenuConfiguration<Option: Hashable & Identifiable> {
    let selection: Option
    let options: [Option]
    let symbol: String
    let helpText: String
    let optionTitle: (Option) -> String
    let onSelect: (Option) -> Void
}

extension MenuBarRootView {
    var footerBar: some View {
        let mihomoRepositoryURL = URL(string: "https://github.com/MetaCubeX/mihomo")
        let mihomoSymbol = "cpu"

        return VStack(spacing: 0) {
            HStack(spacing: T.space6) {
                HStack(spacing: T.space6) {
                    self.footerInfo(
                        tr("ui.footer.core_mihomo", self.footerMihomoVersionText),
                        url: mihomoRepositoryURL,
                        iconSystemName: mihomoSymbol)

                    self.footerCoreUpgradeControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                self.footerVersionInfo
                    .fixedSize(horizontal: true, vertical: false)
            }
            .menuRowPadding(vertical: T.space2)
            .background(self.footerSurfaceBackground)
        }
    }

    var footerSurfaceBackground: some View {
        RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
            .fill(self.nativeControlFill.opacity(self.isDarkAppearance ? 0.54 : 0.38))
            .overlay {
                RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                    .stroke(
                        self.nativeControlBorder.opacity(self.isDarkAppearance ? 0.40 : 0.12),
                        lineWidth: T.stroke)
            }
    }

    var footerMihomoVersionText: String {
        let version = self.appViewModel.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard version.first?.isNumber == true else { return version }
        return "v\(version)"
    }

    @ViewBuilder
    func footerInfo(_ text: String, url: URL?, iconSystemName: String? = nil) -> some View {
        if let url {
            Link(destination: url) {
                self.footerInfoLabel(text, iconSystemName: iconSystemName)
            }
            .buttonStyle(.plain)
        } else {
            self.footerInfoLabel(text, iconSystemName: iconSystemName)
        }
    }

    func footerInfoLabel(_ text: String, iconSystemName: String?) -> some View {
        HStack(spacing: T.space4) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.nativeSecondaryLabel)
            }

            Text(text)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(T.minimumScale)
                .allowsTightening(true)
        }
        .help(text)
    }

    var footerCoreUpgradeControl: some View {
        self.compactAsyncIconButton(
            symbol: self.footerCoreUpgradeButtonSymbolName ?? "arrow.down.circle",
            label: self.footerCoreUpgradeButtonTitle,
            tint: self.footerCoreUpgradeButtonTint,
            baseTint: self.nativeSecondaryLabel,
            isLoading: self.appViewModel.isCoreUpgradeInFlight,
            size: 18,
            fontSize: T.FontSize.caption,
            hierarchicalSymbol: true)
        {
            await self.appViewModel.upgradeCore()
        }
        .disabled(!self.isFooterCoreUpgradeEnabled)
        .help(self.footerCoreUpgradeButtonHelp)
    }

    var isFooterCoreUpgradeEnabled: Bool {
        self.appViewModel.isRuntimeRunning && !self.appViewModel.isCoreUpgradeInFlight
    }

    var footerCoreUpgradeButtonTitle: String {
        switch self.appViewModel.coreUpgradeState {
        case .idle:
            tr("ui.action.upgrade_core")
        case .running:
            tr("ui.footer.core_upgrade.running")
        case .succeeded:
            tr("ui.footer.core_upgrade.success")
        case .alreadyLatest:
            tr("ui.footer.core_upgrade.latest")
        case .failed:
            tr("ui.footer.core_upgrade.failed")
        }
    }

    var footerCoreUpgradeButtonSymbolName: String? {
        switch self.appViewModel.coreUpgradeState {
        case .idle:
            "arrow.down.circle"
        case .running:
            nil
        case .succeeded:
            "checkmark.circle.fill"
        case .alreadyLatest:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var footerCoreUpgradeButtonTint: Color {
        switch self.appViewModel.coreUpgradeState {
        case .idle, .running:
            self.nativeAccent.opacity(T.Opacity.solid)
        case .succeeded, .alreadyLatest:
            self.nativePositive.opacity(T.Opacity.solid)
        case .failed:
            self.nativeCritical.opacity(T.Opacity.solid)
        }
    }

    var footerCoreUpgradeBackground: Color {
        switch self.appViewModel.coreUpgradeState {
        case .idle:
            self.nativeBadgeFill
        case .running:
            self.nativeAccent.opacity(T.Opacity.tint)
        case .succeeded, .alreadyLatest:
            self.nativePositive.opacity(T.Opacity.tint)
        case .failed:
            self.nativeCritical.opacity(T.Opacity.tint)
        }
    }

    var footerCoreUpgradeButtonHelp: String {
        if !self.appViewModel.isRuntimeRunning {
            return tr("ui.footer.core_upgrade.help.disabled")
        }

        switch self.appViewModel.coreUpgradeState {
        case .idle:
            return tr("ui.footer.core_upgrade.help")
        case .running:
            return tr("ui.footer.core_upgrade.help.running")
        case .succeeded:
            return tr("ui.footer.core_upgrade.help.success")
        case let .alreadyLatest(version):
            if let version, !version.isEmpty {
                return tr("ui.footer.core_upgrade.help.latest_version", version)
            }
            return tr("ui.footer.core_upgrade.help.latest")
        case let .failed(message):
            return tr("ui.footer.core_upgrade.help.failed", message)
        }
    }

    @ViewBuilder
    var footerVersionInfo: some View {
        if let update = self.appViewModel.availableAppUpdate {
            Link(destination: update.releaseURL) {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", update.displayVersion),
                    symbol: "arrow.down.circle.fill",
                    tint: self.nativeAccent.opacity(T.Opacity.solid),
                    emphasized: true)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_update_help", update.displayVersion))
            .accessibilityLabel(tr(
                "ui.footer.version_update_accessibility",
                self.appViewModel.currentAppVersionText,
                update.displayVersion))
        } else {
            if let releaseIndexURL = self.appViewModel.appReleaseIndexURL {
                Link(destination: releaseIndexURL) {
                    self.footerVersionBadge(
                        text: tr("ui.footer.version", self.appViewModel.currentAppVersionText),
                        symbol: nil,
                        tint: self.nativeSecondaryLabel,
                        emphasized: false)
                }
                .buttonStyle(.plain)
                .help(tr("ui.footer.version", self.appViewModel.currentAppVersionText))
            } else {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", self.appViewModel.currentAppVersionText),
                    symbol: nil,
                    tint: self.nativeSecondaryLabel,
                    emphasized: false)
            }
        }
    }

    func footerVersionBadge(text: String, symbol: String?, tint: Color, emphasized: Bool) -> some View {
        HStack(spacing: T.space4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
            }

            Text(text)
                .font(.app(
                    size: T.FontSize.caption,
                    weight: emphasized ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(T.minimumScale)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space2)
    }

    var appVersionText: String {
        self.appViewModel.currentAppVersionText
    }
}

extension TranslatingView {
    var statusColor: Color {
        switch appViewModel.runtimeVisualStatus {
        case .runningHealthy: self.nativePositive.opacity(T.Opacity.solid)
        case .runningDegraded: self.nativeWarning.opacity(T.Opacity.solid)
        case .starting: self.nativeInfo.opacity(T.Opacity.solid)
        case .failed: self.nativeCritical.opacity(T.Opacity.solid)
        case .stopped: self.nativeSecondaryLabel
        }
    }

    var runtimeBadgeText: String {
        switch appViewModel.runtimeVisualStatus {
        case .runningHealthy, .runningDegraded: tr("ui.header.status.running")
        case .starting: tr("ui.header.status.starting")
        case .failed: tr("ui.header.status.failed")
        case .stopped: tr("ui.header.status.stopped")
        }
    }
}

extension View {
    var isDarkAppearance: Bool {
        // swiftlint:disable:next implicit_return
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    var nativeAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    var nativeInfo: Color {
        Color(nsColor: .systemBlue)
    }

    var nativePositive: Color {
        Color(nsColor: .systemGreen)
    }

    var nativeWarning: Color {
        Color(nsColor: .systemOrange)
    }

    var nativeCritical: Color {
        Color(nsColor: .systemRed)
    }

    var nativeTeal: Color {
        Color(nsColor: .systemTeal)
    }

    var nativeIndigo: Color {
        Color(nsColor: .systemIndigo)
    }

    var nativePurple: Color {
        Color(nsColor: .systemPurple)
    }

    var nativePrimaryLabel: Color {
        Color(nsColor: .labelColor)
    }

    var nativeBadgeFill: Color {
        Color(nsColor: .quaternaryLabelColor).opacity(T.Opacity.tint)
    }

    var nativeSecondaryLabel: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    var nativeTertiaryLabel: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    var nativeSeparator: Color {
        Color(nsColor: .separatorColor)
    }

    var nativeControlFill: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    var nativeControlBorder: Color {
        Color(nsColor: .separatorColor)
    }

    var nativeHoverFill: Color {
        Color(nsColor: .selectedContentBackgroundColor)
    }

    func nativeHoverRowBackground(
        _ hovered: Bool,
        cornerRadius: CGFloat = T.cornerRadius) -> some View
    {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(hovered ? self.nativeHoverFill : .clear)
    }

    func nativeBadgeCapsule() -> some View {
        Capsule(style: .continuous).fill(self.nativeBadgeFill)
    }

    func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.app(size: T.FontSize.body, weight: .regular))
            .foregroundStyle(self.nativeSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .menuRowPadding()
    }

    func fractionSummaryBadge(current: Int, total: Int) -> some View {
        HStack(spacing: T.space1) {
            Text("\(current)")
                .font(.app(size: T.FontSize.caption, weight: .bold))
                .foregroundStyle(self.nativePrimaryLabel)
            Text("/")
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeTertiaryLabel)
            Text("\(total)")
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
        }
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space2)
        .background(self.nativeBadgeCapsule())
    }

    func compactAsyncIconButton(
        symbol: String,
        label: String,
        tint: Color,
        baseTint: Color? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        size: CGFloat = 20,
        fontSize: CGFloat = T.FontSize.body,
        hierarchicalSymbol: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        CompactAsyncIconButton(
            symbol: symbol,
            tint: tint,
            baseTint: baseTint ?? self.nativeSecondaryLabel,
            role: role,
            isLoading: isLoading,
            size: size,
            fontSize: fontSize,
            hierarchicalSymbol: hierarchicalSymbol,
            action: action)
            .accessibilityLabel(label)
    }

    func compactTopIcon(
        _ symbol: String,
        label: String,
        role: ButtonRole? = nil,
        warning: Bool = false,
        toneOverride: Color? = nil,
        isLoading: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        let tone: Color = if let toneOverride {
            toneOverride
        } else if warning {
            self.nativeCritical
        } else {
            self.nativeSecondaryLabel
        }

        return self.compactAsyncIconButton(
            symbol: symbol,
            label: label,
            tint: tone.opacity(T.Opacity.solid),
            role: role,
            isLoading: isLoading,
            action: action)
    }

    func compactSelectionMenu(
        _ configuration: CompactSelectionMenuConfiguration<some Hashable & Identifiable>) -> some View
    {
        Menu {
            ForEach(configuration.options) { option in
                Button {
                    configuration.onSelect(option)
                } label: {
                    if configuration.selection == option {
                        Label(configuration.optionTitle(option), systemImage: "checkmark")
                    } else {
                        Text(configuration.optionTitle(option))
                    }
                }
            }
        } label: {
            Label(configuration.optionTitle(configuration.selection), systemImage: configuration.symbol)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .lineLimit(1)
        }
        .appBorderedButtonStyle()
        .controlSize(.small)
        .help(configuration.helpText)
    }

    func compareLatency(lhs: Int?, rhs: Int?, ascending: Bool) -> ComparisonResult {
        let leftAvailable = self.isProxyNodeAvailable(lhs)
        let rightAvailable = self.isProxyNodeAvailable(rhs)
        if leftAvailable != rightAvailable {
            return leftAvailable ? .orderedAscending : .orderedDescending
        }
        guard leftAvailable, rightAvailable, let lhs, let rhs, lhs != rhs else {
            return .orderedSame
        }
        return (ascending ? lhs < rhs : lhs > rhs) ? .orderedAscending : .orderedDescending
    }

    func isProxyNodeAvailable(_ latency: Int?) -> Bool {
        guard let latency else { return false }
        return latency > 0
    }

    func latencyColor(_ value: Int?) -> Color {
        guard let value else { return self.nativeTertiaryLabel }
        if value == 0 { return self.nativeCritical.opacity(T.Opacity.solid) }
        if value <= 400 { return self.nativePositive.opacity(T.Opacity.solid) }
        return self.nativeWarning.opacity(T.Opacity.solid)
    }

    func nextHovered<V: Equatable>(current: V?, target: V, isHovering: Bool) -> V? {
        isHovering ? target : (current == target ? nil : current)
    }

    func machineStatusTint(_ status: MachineConnectionStatus) -> Color {
        switch status {
        case .unknown:
            self.nativeSecondaryLabel
        case .checking:
            self.nativeWarning.opacity(T.Opacity.solid)
        case .connected:
            self.nativePositive.opacity(T.Opacity.solid)
        case .failed:
            self.nativeCritical.opacity(T.Opacity.solid)
        }
    }
}

struct CompactAsyncIconButton: View {
    let symbol: String
    let tint: Color
    let baseTint: Color
    let role: ButtonRole?
    let isLoading: Bool
    let size: CGFloat
    let fontSize: CGFloat
    let hierarchicalSymbol: Bool
    let action: () async -> Void

    @State private var hovered = false

    var body: some View {
        Button(role: self.role) {
            Task { await self.action() }
        } label: {
            ZStack {
                Image(systemName: self.symbol)
                    .font(.app(size: self.fontSize, weight: .semibold))
                    .foregroundStyle(self.hovered ? self.tint : self.baseTint)
                    .symbolRenderingMode(self.hierarchicalSymbol ? .hierarchical : .monochrome)
                    .opacity(self.isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.mini)
                    .opacity(self.isLoading ? 1 : 0)
            }
            .frame(width: self.size, height: self.size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(self.isLoading)
        .onHover { self.hovered = $0 }
    }
}
