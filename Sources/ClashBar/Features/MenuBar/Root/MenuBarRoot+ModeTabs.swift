import AppKit
import SwiftUI

private struct ModeSegmentButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isSelected: Bool
    let isDarkAppearance: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && self.isEnabled ? 0.975 : 1)
            .opacity(self.isEnabled ? 1 : (self.isSelected ? 0.90 : (self.isDarkAppearance ? 0.62 : 0.54)))
            .saturation(self.isEnabled ? 1 : 0.72)
            .brightness(configuration.isPressed && self.isEnabled ? -0.02 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

extension MenuBarRoot {
    var modeAndTabSection: some View {
        VStack(spacing: MenuBarLayoutTokens.space6) {
            self.modeSwitcher
            if let hint = self.contextualHintText ?? self.modeSwitcherHintText {
                self.modeSwitcherHint(hint)
                    .transition(.opacity)
            }
            self.topTabs
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(nativeSeparator).frame(height: MenuBarLayoutTokens.stroke)
        }
    }

    var modeSwitcher: some View {
        HStack(spacing: MenuBarLayoutTokens.space2) {
            self.modeSegmentButton(mode: .rule)
            self.modeSegmentButton(mode: .global)
            self.modeSegmentButton(mode: .direct)
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
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.currentMode)
        .animation(.easeOut(duration: 0.14), value: hoveredMode)
        .animation(.easeOut(duration: 0.14), value: switchingMode)
    }

    func modeSegmentButton(mode: CoreMode) -> some View {
        let canInteract = appState.isModeSwitchEnabled && switchingMode == nil
        let selected = appState.currentMode == mode
        let switchingThisMode = switchingMode == mode
        let hovered = hoveredMode == mode
        let tint = self.modeTint(mode)

        return Button {
            if mode == appState.currentMode {
                self.appState.showPanelFeedback(
                    self.modeTooltip(mode: mode),
                    style: .info)
                return
            }

            if !canInteract {
                self.appState.showPanelFeedback(
                    self.modeTooltip(mode: mode),
                    style: .warning)
                return
            }

            switchingMode = mode
            Task { @MainActor in
                await appState.switchMode(to: mode)
                switchingMode = nil
            }
        } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .fill(self.modeSelectionFill(mode: mode, selected: true, hovered: false, switching: false))
                        .matchedGeometryEffect(id: "mode-selection-pill", in: self.modeSwitcherNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                                .stroke(
                                    self.modeSelectionStroke(mode: mode, selected: true, hovered: false, switching: false),
                                    lineWidth: MenuBarLayoutTokens.stroke)
                        }
                        .shadow(
                            color: self.modeSelectionShadow(mode: mode),
                            radius: 8,
                            x: 0,
                            y: 4)
                } else if hovered || switchingThisMode {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .fill(
                            self.modeSelectionFill(
                                mode: mode,
                                selected: false,
                                hovered: hovered,
                                switching: switchingThisMode))
                        .overlay {
                            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                                .stroke(
                                    self.modeSelectionStroke(
                                        mode: mode,
                                        selected: false,
                                        hovered: hovered,
                                        switching: switchingThisMode),
                                    lineWidth: MenuBarLayoutTokens.stroke)
                        }
                }

                VStack(spacing: MenuBarLayoutTokens.space2) {
                    if switchingThisMode {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tint)
                    } else {
                        Image(systemName: self.modeSymbol(mode))
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                            .foregroundStyle(selected ? tint : (hovered ? nativePrimaryLabel : nativeSecondaryLabel))
                    }

                    Text(self.modeTitle(mode))
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(selected ? nativePrimaryLabel : (hovered ? nativePrimaryLabel : nativeSecondaryLabel))
                }
                .padding(.horizontal, MenuBarLayoutTokens.space4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: MenuBarLayoutTokens.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous))
        }
        .buttonStyle(
            ModeSegmentButtonStyle(
                isEnabled: canInteract,
                isSelected: selected,
                isDarkAppearance: self.isDarkAppearance))
        .help(self.modeTooltip(mode: mode))
        .onHover {
            hoveredMode = self.nextHovered(current: hoveredMode, target: mode, isHovering: $0)
            self.contextualHintText = $0 ? self.modeTooltip(mode: mode) : nil
        }
    }

    func modeTitle(_ mode: CoreMode) -> String {
        switch mode {
        case .rule:
            tr("ui.mode.rule")
        case .global:
            tr("ui.mode.global")
        case .direct:
            tr("ui.mode.direct")
        }
    }

    func modeSymbol(_ mode: CoreMode) -> String {
        switch mode {
        case .rule:
            "line.3.horizontal.decrease.circle"
        case .global:
            "globe"
        case .direct:
            "paperplane"
        }
    }

    func modeTint(_ mode: CoreMode) -> Color {
        switch mode {
        case .rule:
            nativePositive
        case .global:
            nativeInfo
        case .direct:
            nativeWarning
        }
    }

    func modeSelectionFill(mode: CoreMode, selected: Bool, hovered: Bool, switching: Bool) -> Color {
        let tint = self.modeTint(mode)
        if selected {
            return tint.opacity(self.isDarkAppearance ? 0.30 : 0.14)
        }
        if switching {
            return tint.opacity(self.isDarkAppearance ? 0.16 : 0.09)
        }
        if hovered {
            return tint.opacity(self.isDarkAppearance ? 0.11 : 0.06)
        }
        return .clear
    }

    func modeSelectionStroke(mode: CoreMode, selected: Bool, hovered: Bool, switching: Bool) -> Color {
        let tint = self.modeTint(mode)
        if selected {
            return tint.opacity(self.isDarkAppearance ? 0.56 : 0.24)
        }
        if switching {
            return tint.opacity(self.isDarkAppearance ? 0.26 : 0.14)
        }
        if hovered {
            return self.nativeControlBorder.opacity(self.isDarkAppearance ? 0.72 : 0.48)
        }
        return .clear
    }

    func modeSelectionShadow(mode: CoreMode) -> Color {
        self.modeTint(mode).opacity(self.isDarkAppearance ? 0.24 : 0.10)
    }

    var modeSwitcherHintText: String? {
        guard switchingMode == nil else { return nil }
        guard !appState.isModeSwitchEnabled else { return nil }

        if !appState.isRuntimeRunning {
            return tr("ui.mode.hint.start_core")
        }

        return tr("ui.mode.hint.wait_api")
    }

    func modeSwitcherHint(_ text: String) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Image(systemName: "info.circle")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(nativeTertiaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuBarLayoutTokens.space4)
    }

    func modeTooltip(mode: CoreMode) -> String {
        let title = self.modeTitle(mode)

        if switchingMode == mode {
            return tr("ui.mode.help.switching", title)
        }

        if appState.currentMode == mode {
            return tr("ui.mode.help.current", title)
        }

        if !appState.isModeSwitchEnabled {
            if !appState.isRuntimeRunning {
                return tr("ui.mode.help.start_core", title)
            }
            return tr("ui.mode.help.wait_api", title)
        }

        return tr("ui.mode.help.switch", title)
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
