import SwiftUI

struct MenuBarHeaderView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var remoteMachineStore: RemoteMachineStore
    @Binding var showRemoteMachineManager: Bool
    @Binding var isSwitchingMachine: Bool

    var headerLogoSize: CGFloat {
        40
    }

    var body: some View {
        self.topHeader
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
                        .font(.app(size: MenuBarLayoutTokens.FontSize.title3, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)

                    HStack(spacing: MenuBarLayoutTokens.space6) {
                        self.headerConnectionControl
                        self.headerControllerWebUIButton
                        if self.appViewModel.isExternalControllerWildcardIPv4 {
                            self.headerControllerWarningIcon
                        }
                    }
                }
            }

            Spacer(minLength: MenuBarLayoutTokens.space6)

            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.compactTopIcon(
                    self.appViewModel.isPinned ? "pin.fill" : "pin",
                    label: self.appViewModel.isPinned ? self.tr("ui.action.unpin") : self.tr("ui.action.pin"),
                    toneOverride: self.appViewModel.isPinned ? nativeInfo : nativeTertiaryLabel)
                {
                    self.appViewModel.togglePinned()
                }

                self.compactTopIcon(
                    "arrow.clockwise",
                    label: self.appViewModel.primaryCoreActionLabel,
                    toneOverride: nativeInfo)
                {
                    await self.appViewModel.performPrimaryCoreAction()
                }
                .disabled(self.appViewModel.isRemoteTarget || !self.appViewModel.isPrimaryCoreActionEnabled)
                .opacity((self.appViewModel.isRemoteTarget || !self.appViewModel.isPrimaryCoreActionEnabled) ? 1 * 0.6 :
                    1)

                self.compactTopIcon(
                    self.appViewModel.isRuntimeRunning ? "stop.circle" : "play.circle",
                    label: self.appViewModel.isRuntimeRunning ? self.tr("ui.action.stop") : self
                        .tr("app.primary.start"),
                    toneOverride: self.appViewModel.isRuntimeRunning ? nativeWarning : nativePositive)
                {
                    if self.appViewModel.isRuntimeRunning {
                        await self.appViewModel.stopCore()
                    } else {
                        await self.appViewModel.startCore(trigger: .manual)
                    }
                }
                .disabled(self.appViewModel.isRemoteTarget || self.appViewModel.isCoreActionProcessing)
                .opacity((self.appViewModel.isRemoteTarget || self.appViewModel.isCoreActionProcessing) ? 0.6 : 1)

                self.compactTopIcon("power", label: self.tr("ui.action.quit"), warning: true) {
                    await self.appViewModel.quitApp()
                }
            }
        }
        .padding(.vertical, MenuBarLayoutTokens.space8)
        .sheet(isPresented: self.$showRemoteMachineManager) {
            RemoteMachineManagerView(
                store: self.remoteMachineStore,
                localControllerDisplay: self.appViewModel.localExternalControllerDisplay)
            { target in
                self.isSwitchingMachine = true
                Task { @MainActor in
                    await self.appViewModel.switchToMachineTarget(target)
                    self.isSwitchingMachine = false
                }
            }
        }
    }

    var headerConnectionControl: some View {
        AttachedPopoverMenu(
            expandAnchor: false,
            onWillPresent: {
                self.remoteMachineStore.checkAllConnectivity()
            },
            label: { _ in
                HStack(spacing: MenuBarLayoutTokens.space6) {
                    if self.isSwitchingMachine {
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
                    title: self.tr("ui.machine.local"),
                    leadingSymbol: "desktopcomputer",
                    leadingTint: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                    selected: self.remoteMachineStore.activeTarget.isLocal,
                    selectionIndicatorPlacement: .trailing)
                {
                    dismiss()
                    guard !self.remoteMachineStore.activeTarget.isLocal else { return }
                    self.isSwitchingMachine = true
                    Task { @MainActor in
                        await self.appViewModel.switchToMachineTarget(.local)
                        self.isSwitchingMachine = false
                    }
                }

                if !self.remoteMachineStore.machines.isEmpty {
                    AttachedPopoverMenuDivider()
                    self.headerPopoverSection(self.tr("ui.machine.remote_label"))
                }

                ForEach(self.remoteMachineStore.machines) { machine in
                    let status = self.remoteMachineStore.statusFor(machine.id)
                    let isSelected = self.remoteMachineStore.activeTargetID == machine.id
                    AttachedPopoverMenuItem(
                        title: machine.name,
                        leadingSymbol: "network",
                        leadingTint: self.machineStatusTint(status),
                        selected: isSelected,
                        selectionIndicatorPlacement: .trailing)
                    {
                        dismiss()
                        guard !isSelected else { return }
                        self.isSwitchingMachine = true
                        Task { @MainActor in
                            await self.appViewModel.switchToMachineTarget(.remote(machine))
                            self.isSwitchingMachine = false
                        }
                    }
                    .disabled(!status.isConnected && !isSelected)
                }

                AttachedPopoverMenuDivider()
                AttachedPopoverMenuItem(
                    title: self.tr("ui.machine.manage"),
                    leadingSymbol: "slider.horizontal.3",
                    leadingTint: self.nativeSecondaryLabel)
                {
                    dismiss()
                    self.showRemoteMachineManager = true
                }
            })
            .disabled(self.isSwitchingMachine)
    }

    var headerControllerWarningIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeWarning)
            .help("external-controller is 0.0.0.0 and can be accessed from your LAN.")
            .accessibilityLabel("Warning: external-controller is bound to 0.0.0.0")
    }

    var headerControllerWebUIButton: some View {
        Button {
            self.appViewModel.openControllerWebUI()
        } label: {
            Image(systemName: "safari")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(self.nativeSecondaryLabel)
        }
        .buttonStyle(.plain)
        .help("Open WebUI")
        .accessibilityLabel("Open WebUI")
        .disabled(self.isSwitchingMachine)
        .opacity(self.isSwitchingMachine ? 0.6 : 1)
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

    var machineSwitcherStatus: MachineConnectionStatus? {
        guard case let .remote(machine) = remoteMachineStore.activeTarget else { return nil }
        return self.remoteMachineStore.statusFor(machine.id)
    }

    var headerConnectionDisplayText: String {
        self.appViewModel.externalControllerDisplay
    }

    var headerConnectionStatusTint: Color {
        if let status = self.machineSwitcherStatus {
            return self.machineStatusTint(status)
        }
        return self.statusColor
    }
}
