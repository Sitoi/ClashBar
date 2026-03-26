import SwiftUI

extension MenuBarRootView {
    var headerLogoSize: CGFloat {
        40
    }

    var topHeader: some View {
        HStack(alignment: .center, spacing: MenuBarLayoutTokens.space8) {
            HStack(alignment: .top, spacing: MenuBarLayoutTokens.space8) {
                ZStack {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .fill(nativeControlFill.opacity(MenuBarLayoutTokens.Opacity.solid))
                        .overlay {
                            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                                .stroke(
                                    nativeControlBorder.opacity(MenuBarLayoutTokens.Opacity.solid),
                                    lineWidth: MenuBarLayoutTokens.stroke)
                        }

                    if let brandImage = BrandIcon.image {
                        Image(nsImage: brandImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: self.headerLogoSize, height: self.headerLogoSize)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .renderingMode(.template)
                            .symbolRenderingMode(.monochrome)
                            .resizable()
                            .scaledToFit()
                            .frame(width: self.headerLogoSize, height: self.headerLogoSize)
                            .foregroundStyle(nativeAccent)
                    }
                }
                .frame(width: self.headerLogoSize, height: self.headerLogoSize)

                VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                    Text("ClashBar")
                        .font(.app(size: MenuBarLayoutTokens.FontSize.title, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)

                    HStack(spacing: MenuBarLayoutTokens.space6) {
                        self.headerConnectionControl
                        if appSession.isExternalControllerWildcardIPv4 {
                            self.headerControllerWarningIcon
                        }
                    }
                }
            }

            Spacer(minLength: MenuBarLayoutTokens.space6)

            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.compactTopIcon(
                    "arrow.clockwise",
                    label: appSession.primaryCoreActionLabel,
                    toneOverride: nativeInfo)
                {
                    await appSession.performPrimaryCoreAction()
                }
                .disabled(appSession.isRemoteTarget || !appSession.isPrimaryCoreActionEnabled)
                .opacity((appSession.isRemoteTarget || !appSession.isPrimaryCoreActionEnabled) ? 1 * 0.6 : 1)

                self.compactTopIcon(
                    appSession.isRuntimeRunning ? "stop.circle" : "play.circle",
                    label: appSession.isRuntimeRunning ? tr("ui.action.stop") : tr("app.primary.start"),
                    toneOverride: appSession.isRuntimeRunning ? nativeWarning : nativePositive)
                {
                    if appSession.isRuntimeRunning {
                        await appSession.stopCore()
                    } else {
                        await appSession.startCore(trigger: .manual)
                    }
                }
                .disabled(appSession.isRemoteTarget || appSession.isCoreActionProcessing)
                .opacity((appSession.isRemoteTarget || appSession.isCoreActionProcessing) ? 0.6 : 1)

                self.compactTopIcon("power", label: tr("ui.action.quit"), warning: true) {
                    await appSession.quitApp()
                }
            }
        }
        .padding(.vertical, MenuBarLayoutTokens.space8)
        .sheet(isPresented: $showRemoteMachineManager) {
            RemoteMachineManagerView(
                store: remoteMachineStore,
                localControllerDisplay: appSession.localExternalControllerDisplay)
            { target in
                isSwitchingMachine = true
                Task { @MainActor in
                    await appSession.switchToMachineTarget(target)
                    isSwitchingMachine = false
                }
            }
        }
    }

    var headerConnectionControl: some View {
        AttachedPopoverMenu(
            expandAnchor: false,
            onWillPresent: {
                remoteMachineStore.checkAllConnectivity()
            },
            label: { _ in
                HStack(spacing: MenuBarLayoutTokens.space6) {
                    if isSwitchingMachine {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 10, height: 10)
                    } else {
                        Circle()
                            .fill(self.headerConnectionStatusTint)
                            .frame(width: 8, height: 8)
                    }

                    Text(self.headerConnectionDisplayText)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                }
                .contentShape(Rectangle())
            },
            content: { dismiss in
                self.headerPopoverSection(self.tr("ui.machine.local_label"))
                AttachedPopoverMenuItem(
                    title: tr("ui.machine.return_local"),
                    selected: remoteMachineStore.activeTarget.isLocal)
                {
                    dismiss()
                    guard !remoteMachineStore.activeTarget.isLocal else { return }
                    isSwitchingMachine = true
                    Task { @MainActor in
                        await appSession.switchToMachineTarget(.local)
                        isSwitchingMachine = false
                    }
                }

                if !remoteMachineStore.machines.isEmpty {
                    AttachedPopoverMenuDivider()
                    self.headerPopoverSection(self.tr("ui.machine.manage"))
                }

                ForEach(remoteMachineStore.machines) { machine in
                    let status = remoteMachineStore.statusFor(machine.id)
                    AttachedPopoverMenuItem(
                        title: machine.name,
                        leadingSymbol: nil,
                        leadingTint: self.machineStatusTint(status),
                        showLeadingDot: true,
                        selected: remoteMachineStore.activeTargetID == machine.id)
                    {
                        dismiss()
                        guard remoteMachineStore.activeTargetID != machine.id else { return }
                        isSwitchingMachine = true
                        Task { @MainActor in
                            await appSession.switchToMachineTarget(.remote(machine))
                            isSwitchingMachine = false
                        }
                    }
                }

                AttachedPopoverMenuDivider()
                AttachedPopoverMenuItem(title: tr("ui.machine.manage")) {
                    dismiss()
                    showRemoteMachineManager = true
                }
            })
            .disabled(isSwitchingMachine)
    }

    var headerControllerWarningIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeWarning)
            .help("external-controller is 0.0.0.0 and can be accessed from your LAN.")
            .accessibilityLabel("Warning: external-controller is bound to 0.0.0.0")
    }

    func headerPopoverSection(_ title: String) -> some View {
        Text(title)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
            .foregroundStyle(nativeTertiaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MenuBarLayoutTokens.space6)
            .padding(.top, MenuBarLayoutTokens.space2)
            .padding(.bottom, MenuBarLayoutTokens.space1)
            .textCase(.uppercase)
    }

    var headerConnectionDisplayText: String {
        appSession.externalControllerDisplay
    }

    var headerConnectionStatusTint: Color {
        if let status = self.machineSwitcherStatus {
            return self.machineStatusTint(status)
        }
        return self.statusColor
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
            nativeCritical
        } else {
            nativeSecondaryLabel
        }

        return self.compactAsyncIconButton(
            symbol: symbol,
            label: label,
            tint: tone.opacity(MenuBarLayoutTokens.Opacity.solid),
            role: role,
            isLoading: isLoading,
            action: action)
    }
}
