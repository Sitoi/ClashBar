import AppKit
import Combine
import SwiftUI

private struct StatusItemRenderKey: Equatable {
    let mode: StatusBarDisplayMode
    let symbolName: String?
    let speedLines: MenuBarSpeedLines?
    let isRunning: Bool
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

private final class PassiveFloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private struct StatusItemPopoverRootView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var popoverLayoutModel: PopoverLayoutModel

    var body: some View {
        MenuBarRootView()
            .environmentObject(self.appViewModel)
            .environmentObject(self.appViewModel.connectionsStore)
            .environmentObject(self.appViewModel.remoteMachineStore)
            .environmentObject(self.popoverLayoutModel)
    }
}

private struct StatusItemBannerRootView: View {
    let banner: StatusItemBanner

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                self.leadingBadge
                    .frame(width: 48, alignment: .leading)

                Spacer(minLength: 0)

                self.successBadge
                    .frame(width: 48, alignment: .trailing)
            }

            VStack(spacing: 4) {
                Text(self.banner.title)
                    .font(.app(size: 11, weight: .semibold))
                    .foregroundStyle(self.nativeSecondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)

                self.detailLine
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 56)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(
            width: StatusItemController.bannerContentSize.width,
            height: StatusItemController.bannerContentSize.height)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(self.panelTint)
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(self.nativeControlBorder.opacity(0.78), lineWidth: 0.8)
        }
        .shadow(
            color: Color(nsColor: .shadowColor).opacity(MenuBarLayoutTokens.Shadow.standard.opacity * 1.12),
            radius: 14,
            x: 0,
            y: 7)
        // Give the SwiftUI shadow bleed room inside the hosting view so
        // it is not clipped at the panel edges. The panel is transparent
        // in this outer band.
        .frame(
            width: StatusItemController.bannerPanelSize.width,
            height: StatusItemController.bannerPanelSize.height,
            alignment: .center)
    }

    private var detailLine: some View {
        HStack(spacing: 7) {
            Text(self.banner.primaryDetail)
                .font(.app(size: 13, weight: .semibold))
                .foregroundStyle(self.nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)

            if let secondaryDetail = self.banner.secondaryDetail?.trimmedNonEmpty {
                Circle()
                    .fill(self.nativeTertiaryLabel)
                    .frame(width: 3, height: 3)

                Text(secondaryDetail)
                    .font(.app(size: 12, weight: .medium))
                    .foregroundStyle(self.nativeSecondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var leadingBadge: some View {
        if let brandImage = BrandIcon.image ?? BrandIcon.runImage {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(self.logoBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(self.iconBorder, lineWidth: 0.8)
                }
                .overlay {
                    Image(nsImage: brandImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                .frame(width: 34, height: 34)
        } else {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(self.logoBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(self.iconBorder, lineWidth: 0.8)
                }
                .overlay {
                    Image(systemName: self.banner.symbolName)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.subhead, weight: .semibold))
                        .foregroundStyle(self.iconForeground)
                }
                .frame(width: 34, height: 34)
        }
    }

    private var successBadge: some View {
        ZStack {
            Circle()
                .stroke(self.nativePositive.opacity(0.9), lineWidth: 2.2)
                .background(
                    Circle()
                        .fill(self.nativePositive.opacity(0.12)))

            Image(systemName: "checkmark")
                .font(.app(size: 11, weight: .bold))
                .foregroundStyle(self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        .frame(width: 26, height: 26)
    }

    private var panelTint: Color {
        self.nativeAccent.opacity(self.isDarkAppearance ? 0.04 : 0.025)
    }

    private var logoBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                self.nativeInfo.opacity(self.isDarkAppearance ? 0.24 : 0.16),
                self.nativeAccent.opacity(self.isDarkAppearance ? 0.16 : 0.1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    private var iconBorder: Color {
        self.nativeInfo.opacity(self.isDarkAppearance ? 0.22 : 0.16)
    }

    private var iconForeground: Color {
        self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let appViewModel: AppViewModel
    private let viewModel: StatusBarViewModel
    private let statusItem: NSStatusItem
    private let panel: FloatingPanel
    private let bannerPanel: PassiveFloatingPanel
    private let statusContentView: StatusItemContentView
    private let popoverLayoutModel = PopoverLayoutModel()
    private let popoverFallbackMaxHeight: CGFloat = 640
    private let popoverScreenPadding: CGFloat = 10
    private let panelTopSpacing: CGFloat = 0
    private let panelHorizontalPadding: CGFloat = MenuBarLayoutTokens.space8
    // Visual capsule top sits `bannerContentTopSpacing` below the menu bar;
    // the hosting panel extends `bannerShadowBleed` above it so SwiftUI's
    // shadow has room to render without hitting the panel edge.
    private let bannerContentTopSpacing: CGFloat = 6
    private var bannerTopSpacing: CGFloat {
        self.bannerContentTopSpacing - Self.bannerShadowBleed
    }

    private var changeCancellable: AnyCancellable?
    private var layoutCancellable: AnyCancellable?
    private var pinStateCancellable: AnyCancellable?
    private var bannerCancellable: AnyCancellable?
    private var refreshWorkItem: DispatchWorkItem?
    private var pendingDisplay: MenuBarDisplay?
    private var pendingRenderKey: StatusItemRenderKey?
    private var lastDisplayRefreshAt: Date = .distantPast
    private var lastRenderedKey: StatusItemRenderKey?
    private var globalEventMonitor: Any?
    private var screenParametersObserver: Any?
    private var lockedPanelOriginX: CGFloat?
    private var popoverHostingController: NSHostingController<StatusItemPopoverRootView>?
    private var bannerHostingController: NSHostingController<StatusItemBannerRootView>?
    private var panelStabilizationTask: Task<Void, Never>?
    private var bannerDismissTask: Task<Void, Never>?

    private let iconOnlyRefreshInterval: TimeInterval = 0.12
    // Status-item snapshotting is expensive on macOS when traffic text changes frequently.
    private let speedDisplayRefreshInterval: TimeInterval = 1.0
    private static let popoverContentWidth: CGFloat = MenuBarLayoutTokens.panelWidth
    // Uniform transparent bleed around the visual capsule; must be ≥ shadow radius+offset.
    fileprivate static let bannerShadowBleed: CGFloat = 24
    fileprivate static let bannerContentSize = NSSize(width: 328, height: 68)
    fileprivate static let bannerPanelSize = NSSize(
        width: bannerContentSize.width + bannerShadowBleed * 2,
        height: bannerContentSize.height + bannerShadowBleed * 2)
    private let bannerDisplayDurationNanoseconds: UInt64 = 2_600_000_000

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.viewModel = StatusBarViewModel(session: appViewModel)
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.popoverContentWidth,
                height: self.popoverLayoutModel.resolvedPanelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true)
        self.bannerPanel = PassiveFloatingPanel(
            contentRect: NSRect(origin: .zero, size: Self.bannerPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)
        self.statusContentView = StatusItemContentView(frame: .zero)

        super.init()

        self.configurePanel()
        self.configureBannerPanel()
        self.configureStatusItem()
        self.bindSession()
        self.bindPopoverLayout()
        self.bindBanner()
        self.observeScreenParameterChanges()
        self.refreshPopoverMaximumHeight()
        self.refreshDisplayNow()
    }

    func shutdown() {
        self.refreshWorkItem?.cancel()
        self.pendingDisplay = nil
        self.pendingRenderKey = nil
        self.panelStabilizationTask?.cancel()
        self.panelStabilizationTask = nil
        self.bannerDismissTask?.cancel()
        self.bannerDismissTask = nil
        self.changeCancellable?.cancel()
        self.layoutCancellable?.cancel()
        self.pinStateCancellable?.cancel()
        self.bannerCancellable?.cancel()
        self.stopGlobalMonitor()
        self.stopObservingScreenParameters()
        self.bannerPanel.orderOut(nil)
        self.unloadPopoverContent()
        self.viewModel.setPanelPresented(false)
        NSStatusBar.system.removeStatusItem(self.statusItem)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if self.panel.isVisible {
            self.closePopover(nil)
            return
        }

        self.ensurePopoverContent()
        self.refreshPopoverMaximumHeight()
        self.applyPopoverSize(
            preferredHeight: self.popoverLayoutModel.resolvedPanelHeight,
            preserveHorizontalPosition: false)
        self.placePanelRelativeToStatusButton(button, preserveHorizontalPosition: false)
        NSApp.activate(ignoringOtherApps: true)
        self.panel.makeKeyAndOrderFront(nil)
        self.placePanelRelativeToStatusButton(button, preserveHorizontalPosition: true)
        self.suppressPanelScrollIndicators()
        self.schedulePanelStabilizationPasses(for: button)
        self.startGlobalMonitor()
        self.viewModel.setPanelPresented(true)
    }

    @objc
    private func closePopover(_ sender: Any?) {
        self.panel.orderOut(sender)
        self.lockedPanelOriginX = nil
        self.panelStabilizationTask?.cancel()
        self.panelStabilizationTask = nil
        self.stopGlobalMonitor()
        self.unloadPopoverContent()
        self.viewModel.setPanelPresented(false)
    }

    private func configurePanel() {
        self.panel.isReleasedWhenClosed = false
        self.panel.isOpaque = false
        self.panel.backgroundColor = .clear
        self.panel.hasShadow = true
        self.panel.acceptsMouseMovedEvents = true
        self.panel.becomesKeyOnlyIfNeeded = false
        self.panel.hidesOnDeactivate = false
        self.panel.level = .statusBar
        self.panel.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]
        self.panel.contentViewController = nil
    }

    private func configureBannerPanel() {
        self.bannerPanel.isReleasedWhenClosed = false
        self.bannerPanel.isOpaque = false
        self.bannerPanel.backgroundColor = .clear
        // SwiftUI draws its own capsule-shaped shadow; NSPanel's rectangular
        // shadow would double up and leak outside the capsule, producing
        // irregular dark edges around the corners.
        self.bannerPanel.hasShadow = false
        self.bannerPanel.ignoresMouseEvents = true
        self.bannerPanel.level = .statusBar
        self.bannerPanel.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]
        self.bannerPanel.alphaValue = 0
        self.bannerPanel.contentViewController = nil
    }

    private func ensurePopoverContent() {
        if self.popoverHostingController == nil {
            let hc = NSHostingController(rootView: self.popoverRootView)
            hc.sizingOptions = [.standardBounds]
            self.popoverHostingController = hc
        } else {
            self.popoverHostingController?.rootView = self.popoverRootView
        }
        self.panel.contentViewController = self.popoverHostingController
        self.suppressPanelScrollIndicators()
    }

    private func unloadPopoverContent() {
        self.panel.contentViewController = nil
        self.popoverHostingController = nil
    }

    private var popoverRootView: StatusItemPopoverRootView {
        StatusItemPopoverRootView(
            appViewModel: self.appViewModel,
            popoverLayoutModel: self.popoverLayoutModel)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = nil
        button.title = ""
        button.target = self
        button.action = #selector(self.togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])

        self.statusContentView.frame = button.bounds
        self.statusContentView.autoresizingMask = [.width, .height]
        button.addSubview(self.statusContentView)
    }

    private func bindSession() {
        self.changeCancellable = self.viewModel.$display
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] display in
                self?.scheduleRefresh(display: display)
            }

        self.pinStateCancellable = self.appViewModel.$isPinned
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPinned in
                self?.handlePinStateChanged(isPinned: isPinned)
            }
    }

    private func handlePinStateChanged(isPinned: Bool) {
        if isPinned {
            self.panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            self.panel.hidesOnDeactivate = false
        } else {
            self.panel.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]
            self.panel.hidesOnDeactivate = false
        }
    }

    private func bindPopoverLayout() {
        self.layoutCancellable = self.popoverLayoutModel.$resolvedPanelHeight
            .receive(on: RunLoop.main)
            .sink { [weak self] preferredHeight in
                self?.applyPopoverSize(preferredHeight: preferredHeight, preserveHorizontalPosition: true)
            }
    }

    private func bindBanner() {
        self.bannerCancellable = self.appViewModel.$statusItemBanner
            .receive(on: RunLoop.main)
            .sink { [weak self] banner in
                guard let self else { return }
                guard let banner else {
                    self.dismissBanner(animated: true)
                    return
                }
                self.presentBanner(banner)
            }
    }

    private func scheduleRefresh(display: MenuBarDisplay) {
        let renderKey = self.renderKey(for: display)
        guard renderKey != self.lastRenderedKey else { return }
        self.pendingDisplay = display
        self.pendingRenderKey = renderKey
        self.flushScheduledRefreshIfNeeded()
    }

    private func refreshDisplayNow() {
        self.refreshWorkItem?.cancel()
        self.refreshWorkItem = nil
        self.pendingDisplay = nil
        self.pendingRenderKey = nil
        let display = self.viewModel.display
        self.refreshDisplay(display, renderKey: self.renderKey(for: display))
        self.lastDisplayRefreshAt = Date()
    }

    private func refreshDisplay(_ display: MenuBarDisplay, renderKey: StatusItemRenderKey) {
        guard renderKey != self.lastRenderedKey else { return }

        self.statusContentView.apply(display: display)
        let requiredWidth = self.statusContentView.requiredWidth
        if abs(self.statusItem.length - requiredWidth) > 0.5 {
            self.statusItem.length = requiredWidth
        }
        self.lastRenderedKey = renderKey
    }

    private func flushScheduledRefreshIfNeeded() {
        guard let pendingDisplay, let pendingRenderKey else { return }

        let refreshInterval = self.refreshInterval(for: pendingDisplay)
        let elapsed = Date().timeIntervalSince(self.lastDisplayRefreshAt)

        if elapsed >= refreshInterval {
            self.refreshWorkItem?.cancel()
            self.refreshWorkItem = nil
            self.pendingDisplay = nil
            self.pendingRenderKey = nil
            self.refreshDisplay(pendingDisplay, renderKey: pendingRenderKey)
            self.lastDisplayRefreshAt = Date()
            return
        }

        guard self.refreshWorkItem == nil else { return }
        let remainingDelay = max(0.01, refreshInterval - elapsed)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refreshWorkItem = nil
            guard let nextDisplay = self.pendingDisplay, let nextRenderKey = self.pendingRenderKey else { return }
            self.pendingDisplay = nil
            self.pendingRenderKey = nil
            self.refreshDisplay(nextDisplay, renderKey: nextRenderKey)
            self.lastDisplayRefreshAt = Date()
            self.flushScheduledRefreshIfNeeded()
        }
        self.refreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay, execute: work)
    }

    private func refreshInterval(for display: MenuBarDisplay) -> TimeInterval {
        switch display.mode {
        case .iconOnly:
            self.iconOnlyRefreshInterval
        case .iconAndSpeed, .speedOnly:
            self.speedDisplayRefreshInterval
        }
    }

    private func renderKey(for display: MenuBarDisplay) -> StatusItemRenderKey {
        let shouldTrackSymbol = !self.statusContentView.usesBrandIcon
        let symbolName = shouldTrackSymbol ? display.symbolName : nil
        switch display.mode {
        case .iconOnly:
            return StatusItemRenderKey(
                mode: .iconOnly,
                symbolName: symbolName,
                speedLines: nil,
                isRunning: display.isRunning)
        case .iconAndSpeed:
            return StatusItemRenderKey(
                mode: .iconAndSpeed,
                symbolName: symbolName,
                speedLines: display.speedLines,
                isRunning: display.isRunning)
        case .speedOnly:
            return StatusItemRenderKey(
                mode: .speedOnly,
                symbolName: nil,
                speedLines: display.speedLines,
                isRunning: display.isRunning)
        }
    }

    private func startGlobalMonitor() {
        self.stopGlobalMonitor()
        self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown,
            .rightMouseDown,
        ]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if !self.appViewModel.isPinned {
                    self.closePopover(nil)
                }
            }
        }
    }

    private func stopGlobalMonitor() {
        guard let globalEventMonitor else { return }
        NSEvent.removeMonitor(globalEventMonitor)
        self.globalEventMonitor = nil
    }

    private func observeScreenParameterChanges() {
        self.screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main)
        { [weak self] _ in
            Task { @MainActor in
                self?.refreshPopoverMaximumHeight()
            }
        }
    }

    private func stopObservingScreenParameters() {
        guard let screenParametersObserver else { return }
        NotificationCenter.default.removeObserver(screenParametersObserver)
        self.screenParametersObserver = nil
    }

    private func refreshPopoverMaximumHeight() {
        let maximumHeight = self.computeMaximumPopoverHeight()
        self.popoverLayoutModel.updateMaximumPanelHeight(maximumHeight)
    }

    private func computeMaximumPopoverHeight() -> CGFloat {
        guard let anchorContext = self.resolvedStatusItemAnchorContext(for: statusItem.button) else {
            return self.popoverFallbackMaxHeight
        }

        return anchorContext.maximumHeightBelowMenuBar(
            screenPadding: self.popoverScreenPadding,
            verticalSpacing: self.panelTopSpacing)
    }

    private func applyPopoverSize(preferredHeight: CGFloat, preserveHorizontalPosition: Bool) {
        let targetSize = NSSize(width: Self.popoverContentWidth, height: preferredHeight)

        let widthChanged = abs(panel.frame.width - targetSize.width) > 0.5
        let heightChanged = abs(panel.frame.height - targetSize.height) > 0.5
        guard widthChanged || heightChanged else { return }

        if self.panel.isVisible,
           let origin = resolvedPanelOrigin(
               for: statusItem.button,
               panelSize: targetSize,
               preserveHorizontalPosition: preserveHorizontalPosition)
        {
            let frame = NSRect(origin: origin, size: targetSize)
            self.panel.setFrame(frame, display: true, animate: false)
            self.suppressPanelScrollIndicators()
            return
        }

        var newFrame = self.panel.frame
        newFrame.size = targetSize
        self.panel.setFrame(newFrame, display: true, animate: false)
        self.suppressPanelScrollIndicators()
    }

    private func schedulePanelStabilizationPasses(for button: NSStatusBarButton) {
        self.panelStabilizationTask?.cancel()
        self.panelStabilizationTask = Task { @MainActor [weak self, weak button] in
            for pass in 0..<11 {
                try? await Task.sleep(nanoseconds: pass == 0 ? 16_000_000 : 40_000_000)

                guard
                    let self,
                    let button,
                    self.panel.isVisible
                else {
                    return
                }

                if pass < 3 {
                    self.refreshPopoverMaximumHeight()
                    self.placePanelRelativeToStatusButton(button, preserveHorizontalPosition: true)
                }

                self.suppressPanelScrollIndicators()
            }
        }
    }

    private func suppressPanelScrollIndicators() {
        ScrollIndicatorPolicy.suppressRecursively(in: self.panel.contentView)
    }

    private func placePanelRelativeToStatusButton(_ button: NSStatusBarButton?, preserveHorizontalPosition: Bool) {
        guard let origin = resolvedPanelOrigin(
            for: button,
            panelSize: panel.frame.size,
            preserveHorizontalPosition: preserveHorizontalPosition)
        else {
            return
        }
        self.panel.setFrameOrigin(origin)
    }

    private func resolvedPanelOrigin(
        for button: NSStatusBarButton?,
        panelSize: NSSize,
        preserveHorizontalPosition: Bool) -> NSPoint?
    {
        guard let anchorContext = self.resolvedStatusItemAnchorContext(for: button) else { return nil }

        let placement = anchorContext.menuBarDropdownPlacement(
            panelSize: panelSize,
            options: MenuBarDropdownPlacementOptions(
                horizontalPadding: self.panelHorizontalPadding,
                verticalSpacing: self.panelTopSpacing,
                screenPadding: self.popoverScreenPadding,
                lockedOriginX: self.lockedPanelOriginX,
                preserveHorizontalPosition: preserveHorizontalPosition))

        self.lockedPanelOriginX = placement.lockedOriginX

        return placement.frame.origin
    }

    private func resolvedStatusItemAnchorContext(for button: NSStatusBarButton?) -> PanelAnchorContext? {
        PanelAnchorContext.resolve(for: button)
    }

    private func presentBanner(_ banner: StatusItemBanner) {
        self.ensureBannerContent(banner)
        self.placeBannerRelativeToStatusButton(self.statusItem.button)

        let shouldAnimate = !self.bannerPanel.isVisible
        if shouldAnimate {
            self.bannerPanel.alphaValue = 0
            self.bannerPanel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.bannerPanel.animator().alphaValue = 1
            }
        } else {
            self.bannerPanel.alphaValue = 1
            self.bannerPanel.orderFrontRegardless()
        }

        self.bannerDismissTask?.cancel()
        let bannerID = banner.id
        self.bannerDismissTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.bannerDisplayDurationNanoseconds ?? 2_600_000_000)
            } catch {
                return
            }

            guard let self, self.appViewModel.statusItemBanner?.id == bannerID else { return }
            self.appViewModel.statusItemBanner = nil
        }
    }

    private func dismissBanner(animated: Bool) {
        self.bannerDismissTask?.cancel()
        self.bannerDismissTask = nil

        guard self.bannerPanel.isVisible else { return }
        let hideBannerIfStillInactive = { [weak self] in
            guard let self, self.appViewModel.statusItemBanner == nil else { return }
            self.bannerPanel.orderOut(nil)
            self.bannerPanel.alphaValue = 0
        }

        guard animated else {
            hideBannerIfStillInactive()
            return
        }

        let animationDuration = 0.16
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.bannerPanel.animator().alphaValue = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            hideBannerIfStillInactive()
        }
    }

    private func ensureBannerContent(_ banner: StatusItemBanner) {
        if self.bannerHostingController == nil {
            self.bannerHostingController = NSHostingController(rootView: StatusItemBannerRootView(banner: banner))
        } else {
            self.bannerHostingController?.rootView = StatusItemBannerRootView(banner: banner)
        }
        self.bannerPanel.contentViewController = self.bannerHostingController
        self.bannerPanel.setContentSize(Self.bannerPanelSize)
    }

    private func placeBannerRelativeToStatusButton(_ button: NSStatusBarButton?) {
        guard
            let anchorContext = self.resolvedStatusItemAnchorContext(for: button)
        else {
            return
        }

        let placement = anchorContext.menuBarDropdownPlacement(
            panelSize: Self.bannerPanelSize,
            options: MenuBarDropdownPlacementOptions(
                horizontalPadding: self.panelHorizontalPadding,
                verticalSpacing: self.bannerTopSpacing,
                screenPadding: self.popoverScreenPadding,
                lockedOriginX: nil,
                preserveHorizontalPosition: false))
        self.bannerPanel.setFrame(placement.frame, display: true, animate: false)
    }
}
