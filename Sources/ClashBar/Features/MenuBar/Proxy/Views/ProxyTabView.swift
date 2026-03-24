import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    func handleCopyProxyCommand(_ action: () -> Void) {
        action()

        self.proxyCommandCopyResetTask?.cancel()
        self.proxyCommandCopyResetTask = nil

        withAnimation(.snappy(duration: 0.16)) {
            self.proxyCommandCopied = true
        }

        self.proxyCommandCopyResetTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_600_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                self.proxyCommandCopied = false
            }
            self.proxyCommandCopyResetTask = nil
        }
    }

    var quickRowTrailingColumnWidth: CGFloat {
        min(170, max(126, contentWidth * 0.44))
    }

    @ViewBuilder
    func configMenuContent(dismiss: @escaping () -> Void) -> some View {
        ForEach(appSession.availableConfigFileNames, id: \.self) { name in
            AttachedPopoverMenuItem(
                title: name,
                selected: name == appSession.selectedConfigName)
            {
                dismiss()
                Task { await appSession.selectConfigFile(named: name) }
            }
        }
        AttachedPopoverMenuDivider()
        AttachedPopoverMenuItem(title: tr("ui.quick.reload_config_list")) {
            dismiss()
            appSession.reloadConfigFileList()
        }
        AttachedPopoverMenuItem(title: tr("ui.quick.import_local_config")) {
            dismiss()
            appSession.importLocalConfigFile()
        }
        AttachedPopoverMenuItem(title: tr("ui.quick.import_remote_config")) {
            dismiss()
            Task { await appSession.importRemoteConfigFile() }
        }
        AttachedPopoverMenuItem(title: tr("ui.quick.update_remote_configs")) {
            dismiss()
            Task { await appSession.updateAllRemoteConfigFiles() }
        }
        AttachedPopoverMenuItem(title: tr("ui.quick.show_in_finder")) {
            dismiss()
            appSession.showSelectedConfigInFinder()
        }
    }

    @ViewBuilder
    func proxyCommandMenuContent(dismiss: @escaping () -> Void) -> some View {
        AttachedPopoverMenuItem(
            title: tr("ui.quick.copy_terminal"),
            subtitle: self.appSession.localProxyCommandTargetDisplay(),
            leadingSymbol: "desktopcomputer",
            leadingTint: nativeInfo)
        {
            dismiss()
            self.handleCopyProxyCommand {
                self.appSession.copyLocalProxyCommand()
            }
        }
        AttachedPopoverMenuItem(
            title: tr("ui.quick.copy_terminal_current_endpoint"),
            subtitle: self.appSession.managedEndpointProxyCommandTargetDisplay(),
            leadingSymbol: "network",
            leadingTint: nativeWarning)
        {
            dismiss()
            self.handleCopyProxyCommand {
                self.appSession.copyManagedEndpointProxyCommand()
            }
        }
    }

    var proxyTabBody: some View {
        VStack(alignment: .leading, spacing: T.space6) {
            self.trafficOverview
            self.proxyQuickRows
            if !appSession.sortedProxyProviderNames.isEmpty {
                proxyProvidersSection
            }
            proxyGroupsSection
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var trafficOverview: some View {
        let sparklineHeight: CGFloat = 64
        let sparklineHorizontalInset = T.space4

        return ZStack {
            TrafficSparklineView(
                upValues: appSession.trafficHistoryUp,
                downValues: appSession.trafficHistoryDown)
                .frame(height: sparklineHeight)
                .padding(.horizontal, sparklineHorizontalInset)

            VStack(spacing: 0) {
                HStack(spacing: T.space6) {
                    self.cornerMetric(
                        symbol: "link",
                        value: "\(connectionsStore.connectionsCount)",
                        color: nativeIndigo)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    self.cornerMetric(
                        symbol: "arrow.up.circle",
                        value: ValueFormatter.speedAndTotal(
                            rate: appSession.traffic.up,
                            total: appSession.displayUpTotal),
                        color: nativeInfo,
                        iconTrailing: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer(minLength: 0)

                HStack(spacing: T.space6) {
                    self.cornerMetric(
                        symbol: "memorychip",
                        value: ValueFormatter.bytesInteger(appSession.memory.inuse),
                        color: nativeTeal)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    self.cornerMetric(
                        symbol: "arrow.down.circle",
                        value: ValueFormatter.speedAndTotal(
                            rate: appSession.traffic.down,
                            total: appSession.displayDownTotal),
                        color: nativePositive.opacity(T.Opacity.solid),
                        iconTrailing: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space2)
        }
        .frame(height: sparklineHeight)
        .padding(.top, T.space2)
    }

    func cornerMetric(
        symbol: String,
        value: String,
        color: Color,
        iconTrailing: Bool = false) -> some View
    {
        let icon = Image(systemName: symbol)
            .font(.app(size: T.FontSize.caption, weight: .semibold))
            .foregroundStyle(color)
        let text = Text(value)
            .font(.app(size: T.FontSize.body, weight: .regular))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .minimumScaleFactor(T.minimumScale)

        return HStack(spacing: iconTrailing ? T.space1 : T.space2) {
            if iconTrailing { text; icon } else { icon; text }
        }
    }

    var proxyQuickRows: some View {
        VStack(spacing: 0) {
            if appSession.isRemoteTarget {
                self.quickRowContent(
                    title: tr("ui.quick.switch_config"),
                    symbol: "doc.text",
                    foreground: nativePurple)
                {
                    Text(tr("ui.machine.remote_readonly"))
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(nativeTertiaryLabel)
                }
            } else {
                AttachedPopoverMenu { _ in
                    self.quickRowContent(
                        title: tr("ui.quick.switch_config"),
                        symbol: "doc.text",
                        foreground: nativePurple)
                    {
                        HStack(spacing: T.space2) {
                            Text(appSession.selectedConfigName)
                                .font(.app(size: T.FontSize.caption, weight: .regular))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(nativeSecondaryLabel)
                            Image(systemName: "chevron.right")
                                .font(.app(size: T.FontSize.caption, weight: .medium))
                                .foregroundStyle(nativeTertiaryLabel)
                        }
                    }
                } content: { dismiss in
                    self.configMenuContent(dismiss: dismiss)
                }
                .buttonStyle(.plain)
            }

            self.quickToggleRow(
                title: self.systemProxyRowTitle,
                symbol: "network",
                foreground: nativeInfo,
                isDisabled: appSession.isProxySyncing,
                isOn: Binding(
                    get: { appSession.isSystemProxyEnabled },
                    set: { value in
                        Task { await appSession.toggleSystemProxy(value) }
                    }))

            self.helperStatusRow

            self.quickToggleRow(
                title: tr("ui.quick.tun_mode"),
                symbol: "shield.lefthalf.filled",
                foreground: nativePositive,
                isDisabled: !appSession.isTunToggleEnabled,
                isOn: Binding(
                    get: { appSession.isTunEnabled },
                    set: { value in
                        Task { await appSession.toggleTunMode(value) }
                    }))

            self.quickRowContent(
                title: tr("ui.quick.copy_terminal"),
                symbol: "terminal",
                foreground: nativeWarning)
            {
                HStack(spacing: T.space2) {
                    Button {
                        self.handleCopyProxyCommand {
                            self.appSession.copyLocalProxyCommand()
                        }
                    } label: {
                        Image(systemName: proxyCommandCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.app(size: T.FontSize.body, weight: .medium))
                            .foregroundStyle(
                                proxyCommandCopied
                                    ? nativePositive.opacity(T.Opacity.solid)
                                    : (hoveringCopyRow ? nativeSecondaryLabel : nativeTertiaryLabel.opacity(0.6)))
                    }
                    .buttonStyle(.plain)

                    AttachedPopoverMenu(expandAnchor: false) { _ in
                        Image(systemName: "chevron.right")
                            .font(.app(size: T.FontSize.caption, weight: .medium))
                            .foregroundStyle(nativeTertiaryLabel)
                    } content: { dismiss in
                        self.proxyCommandMenuContent(dismiss: dismiss)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onHover { hoveringCopyRow = $0 }
        }
    }

    func quickRowContent(
        title: String,
        symbol: String,
        foreground: Color,
        trailingWidth: CGFloat? = nil,
        @ViewBuilder trailing: () -> some View) -> some View
    {
        HStack(spacing: T.space6) {
            self.quickIcon(symbol: symbol, foreground: foreground)
            Text(title)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(T.minimumScale)
            Spacer(minLength: 0)
            trailing()
                .frame(width: trailingWidth ?? self.quickRowTrailingColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, T.space4)
        .padding(.vertical, T.space2)
    }

    var systemProxyRowTitle: String {
        var base = appSession.isRemoteTarget
            ? "\(tr("ui.quick.system_proxy")) (\(tr("ui.machine.local_label")))"
            : tr("ui.quick.system_proxy")
        if let display = appSession.systemProxyActiveDisplay {
            base += " \(display)"
            if appSession.isSystemProxyActiveNonLocal {
                base += " \u{26A0}\u{FE0F}"
            }
        }
        return base
    }

    var systemProxyHelperStatusText: String {
        if self.appSession.systemProxyHelperActionState == .installing {
            return tr("ui.system_proxy.helper.installing")
        }
        if self.appSession.systemProxyHelperActionState == .reinstalling {
            return tr("ui.system_proxy.helper.reinstalling")
        }
        let detail = self.systemProxyHelperDetailText
        switch self.appSession.systemProxyHelperState {
        case .unknown:
            return tr("ui.system_proxy.helper.unknown")
        case .running:
            return tr("ui.system_proxy.helper.running")
        case .failed:
            return detail.map { "\(tr("ui.system_proxy.helper.failed")): \($0)" } ?? tr("ui.system_proxy.helper.failed")
        }
    }

    var systemProxyHelperGuidanceText: String? {
        switch self.appSession.systemProxyHelperIssue {
        case .none:
            nil
        case .notInstalled:
            tr("ui.system_proxy.helper.guidance.not_installed")
        case .registrationFailed, .connectionFailed, .operationFailed, .timeout:
            tr("ui.system_proxy.helper.guidance.reinstall")
        case .systemPolicyBlocked, .needsApproval:
            tr("ui.system_proxy.helper.guidance.system_policy")
        case .signatureMismatch:
            tr("ui.system_proxy.helper.guidance.signature_mismatch")
        case .installLocationInvalid:
            tr("ui.system_proxy.helper.guidance.install_location_invalid")
        case .helperMissing:
            tr("ui.system_proxy.helper.guidance.helper_missing")
        case .permissionDenied:
            tr("ui.system_proxy.helper.guidance.permission_denied")
        case .migrationFailed:
            tr("ui.system_proxy.helper.guidance.migration_failed")
        case .unknown:
            tr("ui.system_proxy.helper.guidance.unknown")
        }
    }

    var systemProxyHelperHoverText: String? {
        guard self.appSession.systemProxyHelperState == .failed else { return nil }

        var sections: [String] = []
        if let guidance = self.systemProxyHelperGuidanceText, !guidance.isEmpty {
            sections.append(guidance)
        }
        if let failureMessage = self.appSession.systemProxyHelperFailureMessage, !failureMessage.isEmpty {
            sections.append(failureMessage)
        }
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    var systemProxyHelperDetailText: String? {
        switch self.appSession.systemProxyHelperIssue {
        case .none:
            nil
        case .notInstalled:
            tr("ui.system_proxy.helper.detail.not_installed")
        case .registrationFailed:
            tr("ui.system_proxy.helper.detail.registration_failed")
        case .systemPolicyBlocked:
            tr("ui.system_proxy.helper.detail.system_policy_blocked")
        case .signatureMismatch:
            tr("ui.system_proxy.helper.detail.signature_mismatch")
        case .needsApproval:
            tr("ui.system_proxy.helper.detail.needs_approval")
        case .installLocationInvalid:
            tr("ui.system_proxy.helper.detail.install_location_invalid")
        case .helperMissing:
            tr("ui.system_proxy.helper.detail.helper_missing")
        case .timeout:
            tr("ui.system_proxy.helper.detail.timeout")
        case .connectionFailed:
            tr("ui.system_proxy.helper.detail.connection_failed")
        case .operationFailed:
            tr("ui.system_proxy.helper.detail.operation_failed")
        case .permissionDenied:
            tr("ui.system_proxy.helper.detail.permission_denied")
        case .migrationFailed:
            tr("ui.system_proxy.helper.detail.migration_failed")
        case .unknown:
            tr("ui.system_proxy.helper.detail.unknown")
        }
    }

    var systemProxyHelperStatusTint: Color {
        switch self.appSession.systemProxyHelperState {
        case .unknown:
            nativeSecondaryLabel
        case .running:
            nativePositive
        case .failed:
            nativeCritical
        }
    }

    func quickToggleRow(
        title: String,
        symbol: String,
        foreground: Color,
        isDisabled: Bool,
        isOn: Binding<Bool>) -> some View
    {
        self.quickRowContent(
            title: title,
            symbol: symbol,
            foreground: foreground,
            trailingWidth: 50)
        {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isDisabled)
        }
    }

    func quickIcon(symbol: String, foreground: Color) -> some View {
        Image(systemName: symbol)
            .font(.app(size: T.FontSize.body, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 18, height: 18, alignment: .center)
    }

    @ViewBuilder
    func helperActionsMenuContent(dismiss: @escaping () -> Void) -> some View {
        AttachedPopoverMenuItem(
            title: tr("ui.system_proxy.helper.install"),
            leadingSymbol: "arrow.down.circle",
            leadingTint: nativeInfo)
        {
            dismiss()
            Task { await appSession.installSystemProxyHelper() }
        }
        AttachedPopoverMenuItem(
            title: tr("ui.system_proxy.helper.reinstall"),
            leadingSymbol: "arrow.triangle.2.circlepath",
            leadingTint: nativeWarning)
        {
            dismiss()
            Task { await appSession.reinstallSystemProxyHelper() }
        }
    }

    var helperStatusRow: some View {
        AttachedPopoverMenu { _ in
            self.quickRowContent(
                title: tr("ui.quick.system_proxy_helper"),
                symbol: "wrench.and.screwdriver",
                foreground: self.systemProxyHelperStatusTint)
            {
                HStack(spacing: T.space2) {
                    self.helperStatusTrailing
                    Image(systemName: "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .medium))
                        .foregroundStyle(nativeTertiaryLabel)
                }
            }
        } content: { dismiss in
            self.helperActionsMenuContent(dismiss: dismiss)
        }
        .buttonStyle(.plain)
    }

    var helperStatusTrailing: some View {
        HStack(spacing: T.space2) {
            Text(self.systemProxyHelperStatusText)
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .lineLimit(1)
                .foregroundStyle(nativeSecondaryLabel)

            if let hoverText = self.systemProxyHelperHoverText {
                Button {
                    self.showingSystemProxyHelperDetails = true
                } label: {
                    Image(systemName: self.appSession.systemProxyHelperState == .failed
                        ? "exclamationmark.circle.fill"
                        : "info.circle")
                        .font(.app(size: T.FontSize.caption, weight: .medium))
                        .foregroundStyle(
                            self.appSession.systemProxyHelperState == .failed
                                ? nativeWarning
                                : nativeTertiaryLabel)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSystemProxyHelperDetails, arrowEdge: .top) {
                    ScrollView {
                        Text(hoverText)
                            .font(.app(size: T.FontSize.caption, weight: .regular))
                            .foregroundStyle(nativePrimaryLabel)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(T.space6)
                    }
                    .frame(width: 360, height: 220)
                }
            }
        }
    }
}
