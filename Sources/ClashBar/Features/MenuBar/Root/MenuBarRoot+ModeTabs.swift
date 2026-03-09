import AppKit
import SwiftUI

extension MenuBarRoot {
    var modeAndTabSection: some View {
        VStack(spacing: MenuBarLayoutTokens.sectionGap) {
            self.modeSwitcher
            self.topTabs
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(nativeSeparator).frame(height: MenuBarLayoutTokens.hairline)
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
                symbol: "paperplane")
        }
        .padding(2)
        .frame(width: contentWidth)
        .background(
            nativeControlFill,
            in: RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cardCornerRadius, style: .continuous)
                .stroke(nativeControlBorder, lineWidth: 0.7)
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
            VStack(spacing: 2) {
                if switchingThisMode {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .font(.appSystem(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(.appSystem(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle((selected || hovered) ? nativePrimaryLabel : nativeSecondaryLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.iconCornerRadius, style: .continuous)
                    .fill(
                        selected
                            ? nativeAccent.opacity(0.16)
                            : (hovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.20) : .clear)))
            .overlay {
                if selected || hovered {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.iconCornerRadius, style: .continuous)
                        .stroke(
                            selected ? nativeAccent.opacity(0.30) : nativeControlBorder.opacity(0.82),
                            lineWidth: 0.7)
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
        control.selectedSegment = selectedIndex
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        for (i, label) in labels.enumerated() {
            if control.label(forSegment: i) != label {
                control.setLabel(label, forSegment: i)
            }
        }
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
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
            guard index >= 0, index < parent.labels.count else { return }
            parent.selectedIndex = index
        }
    }
}
