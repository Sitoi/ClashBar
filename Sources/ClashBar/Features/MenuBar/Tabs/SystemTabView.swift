import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRoot {
    func settingsCardHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
            Text(title)
                .font(.app(size: T.FontSize.body, weight: .bold))
                .foregroundStyle(nativeTertiaryLabel)
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .menuRowPadding(vertical: T.space2)
    }

    func settingsRowLabel(symbol: String, title: String) -> some View {
        HStack(spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
                .frame(width: 14, alignment: .center)
            Text(title)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    func settingsToggleRow(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .menuRowPadding(vertical: T.space4)
    }

    func settingsMenuRow(
        _ title: String,
        symbol: String,
        valueText: String,
        controlWidth: CGFloat? = nil,
        popoverWidth: CGFloat? = nil,
        @ViewBuilder options: @escaping (_ dismiss: @escaping () -> Void) -> some View) -> some View
    {
        let resolvedControlWidth = controlWidth ?? self.settingsMenuControlWidth

        return HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)
            Spacer(minLength: 0)
            AttachedPopoverMenu(width: popoverWidth ?? resolvedControlWidth) { _ in
                HStack(spacing: T.space2) {
                    Text(valueText)
                        .foregroundStyle(nativeSecondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                }
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
            } content: { dismiss in
                options(dismiss)
            }
            .frame(width: resolvedControlWidth, alignment: .trailing)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .menuRowPadding(vertical: T.space4)
    }

    // swiftlint:disable:next function_parameter_count
    func settingsSelectionRow<Option: Hashable>(
        _ title: String,
        symbol: String,
        valueText: String,
        options: [Option],
        optionTitle: @escaping (Option) -> String,
        isSelected: @escaping (Option) -> Bool,
        onSelect: @escaping (Option) -> Void) -> some View
    {
        self.settingsMenuRow(title, symbol: symbol, valueText: valueText) { dismiss in
            ForEach(options, id: \.self) { option in
                AttachedPopoverMenuItem(
                    title: optionTitle(option),
                    selected: isSelected(option))
                {
                    onSelect(option)
                    dismiss()
                }
            }
        }
    }

    func settingsPortFieldRow(_ title: String, symbol: String, text: Binding<String>) -> some View {
        HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)

            Spacer(minLength: 0)

            TextField(tr("ui.placeholder.port"), text: text)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: T.FontSize.body, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
                .multilineTextAlignment(.trailing)
                .frame(width: self.settingsPortFieldWidth, alignment: .trailing)
                .onChange(of: text.wrappedValue) { _ in
                    appState.scheduleProxyPortsAutoSaveIfNeeded()
                }
                .onSubmit {
                    Task { await appState.applyProxyPorts(autoSaved: true) }
                }
        }
    }

    func maintenanceActionButton(_ title: String, symbol: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label {
                Text(title)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            } icon: {
                Image(systemName: symbol)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!self.maintenanceActionEnabled)
        .opacity(self.maintenanceActionEnabled ? 1 : 0.62)
    }

    func settingsFeedbackBanner(text: String, color: Color, symbol: String) -> some View {
        HStack(spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(color)

            Text(text)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .menuRowPadding(vertical: T.space4)
        .background {
            RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                .fill(nativeControlFill)
                .overlay {
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .stroke(color.opacity(0.26), lineWidth: T.stroke)
                }
                .shadow(
                    color: Color(nsColor: .shadowColor).opacity(T.Shadow.standard.opacity),
                    radius: T.Shadow.standard.radius,
                    x: T.Shadow.standard.x,
                    y: T.Shadow.standard.y)
        }
    }

    func statusBarModeLabel(_ mode: StatusBarDisplayMode) -> String {
        switch mode {
        case .iconAndSpeed:
            tr("ui.settings.display_mode.icon_and_speed")
        case .iconOnly:
            tr("ui.settings.display_mode.icon_only")
        case .speedOnly:
            tr("ui.settings.display_mode.speed_only")
        }
    }

    func appearanceModeLabel(_ mode: AppAppearanceMode) -> String {
        switch mode {
        case .system:
            tr("ui.settings.appearance.system")
        case .light:
            tr("ui.settings.appearance.light")
        case .dark:
            tr("ui.settings.appearance.dark")
        }
    }

    var settingsMenuControlWidth: CGFloat {
        min(152, max(118, contentWidth * 0.43))
    }

    var settingsPortFieldWidth: CGFloat {
        min(108, max(92, contentWidth * 0.30))
    }

    var maintenanceActionEnabled: Bool {
        appState.isRemoteTarget || appState.processManager.isRunning || appState.statusText.lowercased() == "running"
    }

    var portAutoSaving: Bool {
        appState.settingsSyncingKey == "ports-auto" || appState.settingsSyncingKey == "ports"
    }

    var settingsFeedbackState: (message: String, color: Color, symbol: String)? {
        if let error = appState.settingsErrorMessage.trimmedNonEmpty {
            return (error, nativeCritical.opacity(T.Opacity.solid), "exclamationmark.triangle.fill")
        }

        if let launchError = appState.launchAtLoginErrorMessage.trimmedNonEmpty {
            return (launchError, nativeWarning.opacity(T.Opacity.solid), "exclamationmark.circle.fill")
        }

        if let saved = appState.settingsSavedMessage.trimmedNonEmpty {
            return (saved, nativePositive.opacity(T.Opacity.solid), "checkmark.circle.fill")
        }

        return nil
    }

    func editableCoreSettingBinding(_ setting: AppState.EditableCoreSetting) -> Binding<Bool> {
        Binding(
            get: { self.appState.boolValue(for: setting) },
            set: { value in
                Task { await self.appState.applyEditableCoreSetting(setting, to: value) }
            })
    }

    var systemTabBody: some View {
        let isRemote = appState.isRemoteTarget
        let proxyPortFields: [(titleKey: String, symbol: String, text: Binding<String>)] = [
            ("ui.settings.port.port", "network", $appState.settingsPort),
            ("ui.settings.port.socks", "wave.3.right", $appState.settingsSocksPort),
            ("ui.settings.port.mixed", "arrow.triangle.merge", $appState.settingsMixedPort),
            ("ui.settings.port.redir", "arrowshape.turn.up.right", $appState.settingsRedirPort),
            ("ui.settings.port.tproxy", "shield.lefthalf.filled", $appState.settingsTProxyPort),
        ]
        let localOnlyItems: [(id: String, title: String, symbol: String, isOn: Binding<Bool>)] = [
            (
                "launch-at-login",
                tr("ui.settings.launch_at_login"),
                "person.crop.circle.badge.checkmark",
                Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.applyLaunchAtLogin($0) })),
            (
                "auto-start-core",
                tr("ui.settings.auto_start_core"),
                "power.circle",
                Binding(
                    get: { appState.autoStartCoreEnabled },
                    set: { appState.autoStartCoreEnabled = $0 })),
            (
                "auto-core-network-recovery",
                tr("ui.settings.auto_core_network_recovery"),
                "network.badge.shield.half.filled",
                Binding(
                    get: { appState.autoManageCoreOnNetworkChangeEnabled },
                    set: { appState.autoManageCoreOnNetworkChangeEnabled = $0 })),
        ]
        let coreToggleItems: [(id: String, title: String, symbol: String, isOn: Binding<Bool>)] = [
            (
                AppState.EditableCoreSetting.allowLan.id,
                tr("ui.settings.allow_lan"),
                "network",
                self.editableCoreSettingBinding(.allowLan)),
            (
                AppState.EditableCoreSetting.ipv6.id,
                tr("ui.settings.ipv6"),
                "globe",
                self.editableCoreSettingBinding(.ipv6)),
            (
                AppState.EditableCoreSetting.tcpConcurrent.id,
                tr("ui.settings.tcp_concurrent"),
                "point.3.connected.trianglepath.dotted",
                self.editableCoreSettingBinding(.tcpConcurrent)),
        ]
        let maintenanceActions: [(titleKey: String, symbol: String, action: @MainActor () async -> Void)] = [
            ("ui.action.flush_fakeip_cache", "externaldrive.badge.minus", { await appState.flushFakeIPCache() }),
            ("ui.action.flush_dns_cache", "network.badge.shield.half.filled", { await appState.flushDNSCache() }),
        ]
        let selectedLogLevel = appState.stringValue(for: .logLevel)

        return VStack(alignment: .leading, spacing: T.space6) {
            VStack(spacing: 0) {
                self.settingsCardHeader(
                    isRemote ? tr("ui.section.local_app_settings") : tr("ui.section.basic_settings"),
                    symbol: "slider.horizontal.3")
                ForEach(localOnlyItems, id: \.id) { item in
                    self.settingsToggleRow(
                        isRemote ? "\(item.title) (\(tr("ui.machine.local_label")))" : item.title,
                        symbol: item.symbol,
                        isOn: item.isOn)
                }
                self.settingsSelectionRow(
                    tr("ui.settings.menu_bar_style"),
                    symbol: "menubar.rectangle",
                    valueText: self.statusBarModeLabel(appState.statusBarDisplayMode),
                    options: StatusBarDisplayMode.allCases,
                    optionTitle: self.statusBarModeLabel,
                    isSelected: { appState.statusBarDisplayMode == $0 },
                    onSelect: { appState.statusBarDisplayMode = $0 })
                self.settingsSelectionRow(
                    tr("ui.settings.language"),
                    symbol: "character.book.closed",
                    valueText: appState.uiLanguage == .zhHans ? tr("ui.language.zh_hans") : tr("ui.language.en"),
                    options: AppLanguage.allCases,
                    optionTitle: { $0 == .zhHans ? tr("ui.language.zh_hans") : tr("ui.language.en") },
                    isSelected: { appState.uiLanguage == $0 },
                    onSelect: appState.setUILanguage)
                self.settingsSelectionRow(
                    tr("ui.settings.appearance"),
                    symbol: "circle.lefthalf.filled",
                    valueText: self.appearanceModeLabel(appState.appearanceMode),
                    options: AppAppearanceMode.allCases,
                    optionTitle: self.appearanceModeLabel,
                    isSelected: { appState.appearanceMode == $0 },
                    onSelect: appState.setAppearanceMode)
                self.settingsSelectionRow(
                    tr("ui.settings.log_level"),
                    symbol: "text.alignleft",
                    valueText: selectedLogLevel,
                    options: ConfigLogLevel.allCases,
                    optionTitle: \.rawValue,
                    isSelected: { selectedLogLevel.caseInsensitiveCompare($0.rawValue) == .orderedSame },
                    onSelect: { level in
                        Task { await appState.applyEditableCoreSetting(.logLevel, to: level.rawValue) }
                    })
            }

            VStack(spacing: 0) {
                self.settingsCardHeader(
                    isRemote ? tr("ui.section.core_settings_remote") : tr("ui.section.core_settings"),
                    symbol: "gearshape.2")
                ForEach(coreToggleItems, id: \.id) { item in
                    self.settingsToggleRow(item.title, symbol: item.symbol, isOn: item.isOn)
                }
            }

            VStack(spacing: 0) {
                self.settingsCardHeader(
                    tr("ui.section.proxy_ports"),
                    symbol: "point.3.connected.trianglepath.dotted")

                VStack(alignment: .leading, spacing: T.space4) {
                    ForEach(proxyPortFields, id: \.titleKey) { item in
                        self.settingsPortFieldRow(
                            tr(item.titleKey),
                            symbol: item.symbol,
                            text: item.text)
                    }
                }
                .menuRowPadding(vertical: T.space4)
            }

            VStack(spacing: 0) {
                self.settingsCardHeader(
                    tr("ui.section.maintenance"),
                    symbol: "wrench.and.screwdriver")

                VStack(alignment: .leading, spacing: T.space4) {
                    HStack(spacing: T.space6) {
                        ForEach(maintenanceActions, id: \.titleKey) { item in
                            self.maintenanceActionButton(tr(item.titleKey), symbol: item.symbol) {
                                await item.action()
                            }
                        }
                    }

                    HStack(spacing: T.space6) {
                        Button {
                            appState.showCoreDirectoryInFinder()
                        } label: {
                            Label(tr("ui.action.open_core_directory"), systemImage: "folder")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .menuRowPadding(vertical: T.space4)
            }
        }
        .overlay(alignment: .top) {
            if let feedback = settingsFeedbackState {
                self.settingsFeedbackBanner(
                    text: feedback.message,
                    color: feedback.color,
                    symbol: feedback.symbol)
            }
        }
    }
}
