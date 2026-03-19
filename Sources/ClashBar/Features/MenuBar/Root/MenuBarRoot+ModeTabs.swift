import AppKit
import SwiftUI

extension MenuBarRoot {
    var modeAndTabSection: some View {
        VStack(spacing: MenuBarLayoutTokens.space6) {
            self.machineSwitcherBar
            self.modeSwitcher
            self.topTabs
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showRemoteMachineManager) {
            RemoteMachineManagerView(store: remoteMachineStore) { target in
                isSwitchingMachine = true
                Task { @MainActor in
                    await appState.switchToMachineTarget(target)
                    isSwitchingMachine = false
                }
            }
            .frame(width: 360, height: 400)
        }
    }

    var machineSwitcherBar: some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Menu {
                Button {
                    guard !remoteMachineStore.activeTarget.isLocal else { return }
                    isSwitchingMachine = true
                    Task { @MainActor in
                        await appState.switchToMachineTarget(.local)
                        isSwitchingMachine = false
                    }
                } label: {
                    if remoteMachineStore.activeTarget.isLocal {
                        Label(tr("ui.machine.return_local"), systemImage: "checkmark")
                    } else {
                        Text(tr("ui.machine.return_local"))
                    }
                }

                if !remoteMachineStore.machines.isEmpty {
                    Divider()
                }

                ForEach(remoteMachineStore.machines) { machine in
                    let status = remoteMachineStore.statusFor(machine.id)
                    Button {
                        guard remoteMachineStore.activeTargetID != machine.id else { return }
                        isSwitchingMachine = true
                        Task { @MainActor in
                            await appState.switchToMachineTarget(.remote(machine))
                            isSwitchingMachine = false
                        }
                    } label: {
                        if remoteMachineStore.activeTargetID == machine.id {
                            Label("\(machine.name) (\(status.shortLabel))", systemImage: "checkmark")
                        } else {
                            Text("\(machine.name) (\(status.shortLabel))")
                        }
                    }
                }
            } label: {
                HStack(spacing: MenuBarLayoutTokens.space4) {
                    if isSwitchingMachine {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: remoteMachineStore.activeTarget.isLocal
                            ? "desktopcomputer" : "network")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    }

                    Text(self.machineSwitcherLabel)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isSwitchingMachine)
            .onAppear {
                remoteMachineStore.checkAllConnectivity()
            }
            .simultaneousGesture(TapGesture().onEnded {
                remoteMachineStore.checkAllConnectivity()
            })

            Spacer()

            Button {
                showRemoteMachineManager = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(tr("ui.machine.manage"))
        }
        .frame(width: contentWidth)
    }

    private var machineSwitcherLabel: String {
        switch remoteMachineStore.activeTarget {
        case .local:
            tr("ui.machine.local")
        case let .remote(machine):
            machine.name
        }
    }

    var modeSwitcher: some View {
        HStack(spacing: 0) {
            self.modeSegmentButton(
                title: tr("ui.mode.rule"),
                mode: .rule,
                symbol: "line.3.horizontal.decrease.circle")
            self.modeSegmentButton(
                title: tr("ui.mode.global"),
                mode: .global,
                symbol: "globe")
            self.modeSegmentButton(
                title: tr("ui.mode.direct"),
                mode: .direct,
                symbol: "arrow.forward.circle")
        }
        .padding(MenuBarLayoutTokens.space2)
        .frame(width: contentWidth)
        .background(
            nativeControlFill,
            in: RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                .stroke(nativeControlBorder, lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    func modeSegmentButton(title: String, mode: CoreMode, symbol: String) -> some View {
        let selected = appState.currentMode == mode
        let switchingThisMode = switchingMode == mode
        let hovered = hoveredMode == mode

        return Button {
            if !appState.isModeSwitchEnabled || switchingMode != nil || mode == appState.currentMode { return }

            switchingMode = mode
            Task { @MainActor in
                await appState.switchMode(to: mode)
                switchingMode = nil
            }
        } label: {
            VStack(spacing: MenuBarLayoutTokens.space2) {
                if switchingThisMode {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                }

                Text(title)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle((selected || hovered) ? nativePrimaryLabel : nativeSecondaryLabel)
            .frame(maxWidth: .infinity)
            .frame(height: MenuBarLayoutTokens.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                    .fill(
                        selected
                            ? nativeAccent.opacity(MenuBarLayoutTokens.Opacity.tint)
                            :
                            (hovered ? Color(nsColor: .selectedContentBackgroundColor)
                                .opacity(MenuBarLayoutTokens.Opacity.tint) : .clear)))
            .overlay {
                if selected || hovered {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .stroke(
                            selected ? nativeAccent.opacity(MenuBarLayoutTokens.Opacity.tint) : nativeControlBorder
                                .opacity(isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark
                                    .borderEmphasis : MenuBarLayoutTokens.Theme.Light.borderEmphasis),
                            lineWidth: MenuBarLayoutTokens.stroke)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hoveredMode = self.nextHovered(
            current: hoveredMode, target: mode, isHovering: $0) }
    }

    var topTabs: some View {
        let tabs = RootTab.allCases
        let labels = tabs.map { self.tr($0.titleKey) }
        let selectedIndex = Binding<Int>(
            get: { tabs.firstIndex(of: self.currentTab) ?? 0 },
            set: { index in
                guard tabs.indices.contains(index) else { return }
                self.setCurrentTabWithoutAnimation(tabs[index])
            })

        return EqualWidthSegmentedControl(labels: labels, selectedIndex: selectedIndex)
            .frame(width: contentWidth, height: 24)
    }
}

@MainActor
private struct EqualWidthSegmentedControl: NSViewRepresentable {
    let labels: [String]
    @Binding var selectedIndex: Int

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: labels,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:)))
        control.segmentDistribution = .fillEqually
        control.selectedSegment = self.selectedIndex
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        for (index, label) in self.labels.enumerated() where control.label(forSegment: index) != label {
            control.setLabel(label, forSegment: index)
        }
        if control.selectedSegment != self.selectedIndex {
            control.selectedSegment = self.selectedIndex
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let height = nsView.intrinsicContentSize.height
        guard let width = proposal.width else {
            return CGSize(width: nsView.intrinsicContentSize.width, height: height)
        }
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: EqualWidthSegmentedControl

        init(_ parent: EqualWidthSegmentedControl) {
            self.parent = parent
        }

        @MainActor @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0, index < self.parent.labels.count else { return }
            self.parent.selectedIndex = index
        }
    }
}
