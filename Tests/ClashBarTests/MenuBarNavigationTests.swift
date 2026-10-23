import AppKit
import Combine
import SwiftUI
import XCTest
@testable import ClashBar

private enum NavigationTestReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var navigationTestReduceMotion: Bool {
        get { self[NavigationTestReduceMotionKey.self] }
        set { self[NavigationTestReduceMotionKey.self] = newValue }
    }
}

final class MenuBarNavigationTests: XCTestCase {
    @MainActor
    func testRapidTabChangesKeepFinalSelectionAndRecalculateHeight() throws {
        try self.exerciseNavigation(reduceMotion: false, colorScheme: .dark)
    }

    @MainActor
    func testReducedMotionNavigationRecalculatesHeight() throws {
        try self.exerciseNavigation(reduceMotion: true, colorScheme: .light)
    }

    @MainActor
    private func exerciseNavigation(reduceMotion: Bool, colorScheme: ColorScheme) throws {
        let app = NSApplication.shared
        guard let screen = NSScreen.main else {
            throw XCTSkip("Requires a macOS window server")
        }
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let initialPanelIDs = Set(app.windows.filter { $0 is NSPanel }.map(ObjectIdentifier.init))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let working = WorkingDirectoryManager(homeDirectory: directory)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ClashBar.NavigationTests.\(UUID().uuidString)"))
        let machines = RemoteMachineStore(session: URLSession(configuration: .ephemeral), defaults: defaults)
        let model = AppViewModel(dependencies: AppDependencies(
            processManager: MihomoProcessManager(workingDirectoryManager: working),
            configService: ConfigService(
                configManager: ConfigDirectoryManager(workingDirectoryManager: working),
                configImportService: ConfigImportService()),
            systemProxyService: SystemProxyService(),
            tunPermissionService: TunPermissionService(),
            launchAtLoginService: AppLaunchService(),
            workingDirectoryManager: working,
            networkReachabilityMonitor: NetworkReachabilityMonitor(),
            ssidMonitorService: SSIDMonitorService(),
            remoteMachineStore: machines,
            proxyGroupIconCache: .unavailable,
            clashbarLogStore: AppLogStore(logFileURL: directory.appendingPathComponent("app.log")),
            mihomoLogStore: AppLogStore(logFileURL: directory.appendingPathComponent("core.log"))))
        model.uiLanguage = .zhHans

        let previousDefaults = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        var isolatedDefaults = previousDefaults
        isolatedDefaults[model.systemProxyEnabledOnQuitKey] = false
        isolatedDefaults["AppleShowScrollBars"] = "Always"
        UserDefaults.standard.setVolatileDomain(isolatedDefaults, forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(previousDefaults, forName: UserDefaults.argumentDomain) }

        let layout = PopoverLayoutModel(maxPanelHeight: 640, preferredPanelHeight: 640)
        let root = MenuBarRootView(reduceMotion: Environment(\.navigationTestReduceMotion))
            .environmentObject(model)
            .environmentObject(model.proxyStore)
            .environmentObject(model.trafficStore)
            .environmentObject(model.logsStore)
            .environmentObject(model.connectionsStore)
            .environmentObject(machines)
            .environmentObject(layout)
            .environment(\.colorScheme, colorScheme)
            .environment(\.navigationTestReduceMotion, reduceMotion)
            .frame(width: 360, alignment: .topLeading)
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: screen.visibleFrame.minX + 100, y: screen.visibleFrame.minY + 100,
                                width: 360, height: 640),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        defer {
            window.contentView = nil
            window.close()
            model.cancelOwnedTasks()
            try? FileManager.default.removeItem(at: directory)
        }
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let initialHeight = layout.resolvedPanelHeight

        model.activeMenuTab = .system
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let settingsHeight = layout.resolvedPanelHeight
        XCTAssertGreaterThan(settingsHeight, initialHeight)
        model.activeMenuTab = .logs
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let logsHeight = layout.resolvedPanelHeight
        XCTAssertLessThan(logsHeight, settingsHeight)
        layout.resizePanelHeight(to: 580, minimum: 280)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(layout.resolvedPanelHeight, 580, accuracy: 0.5)
        model.activeMenuTab = .system
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        XCTAssertNil(layout.userPanelHeight)
        XCTAssertEqual(layout.resolvedPanelHeight, settingsHeight, accuracy: 0.5)

        for (index, tab) in [RootTab.system, .connections, .rules, .proxy, .logs].enumerated() {
            let column = try XCTUnwrap(RootTab.allCases.firstIndex(of: tab))
            let x = 8 + CGFloat(column) * 69.2 + 33.6
            for (offset, type) in [NSEvent.EventType.leftMouseDown, .leftMouseUp].enumerated() {
                let event = try XCTUnwrap(NSEvent.mouseEvent(
                    with: type, location: NSPoint(x: x, y: 534 - MenuBarLayoutTokens.panelDragHandleHeight), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: index * 2 + offset + 1, clickCount: 1, pressure: 1))
                app.sendEvent(event)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            XCTAssertEqual(model.activeMenuTab, tab)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        XCTAssertEqual(model.activeMenuTab, .logs)
        XCTAssertEqual(layout.resolvedPanelHeight, logsHeight, accuracy: 0.5)

        model.proxyStore.proxyGroups = (0..<50).map {
            ProxyGroup(name: "Group \($0)", type: "Selector", now: "DIRECT", all: ["DIRECT"])
        }
        model.proxyStore.ruleItems = (0..<50).map {
            RuleItem(type: "DOMAIN", payload: "host\($0).example", proxy: "DIRECT")
        }
        model.proxyStore.rulesCount = 50
        model.connectionsStore.connections = (0..<50).map {
            ConnectionSummary(id: "\($0)", upload: 128, download: 256, start: nil,
                              rule: "DOMAIN", rulePayload: "host\($0).example", chains: ["DIRECT"], metadata: nil)
        }
        model.connectionsStore.connectionsCount = 50
        model.logsStore.errorLogs = (0..<50).map {
            AppErrorLogEntry(level: "info", message: "Connection \($0) established")
        }

        for tab in RootTab.allCases {
            model.activeMenuTab = tab
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let scroll = try self.contentScrollView(in: hosting)
            let unusedPanels = app.windows.filter { $0 is NSPanel && !initialPanelIDs.contains(ObjectIdentifier($0)) }
            XCTAssertEqual(unusedPanels.count, 0, "Unopened menus should not allocate native panels: \(tab)")
            XCTAssertFalse(scroll.hasVerticalScroller, "Unexpected scrollbar after switching to \(tab)")
            XCTAssertEqual(scroll.contentView.frame.width, scroll.bounds.width, accuracy: 0.5,
                           "Scrollbar must not reserve a gutter: \(tab)")
            let frame = scroll.convert(scroll.bounds, to: nil)
            let fixedTopHeight = 640 - frame.maxY
            XCTAssertGreaterThan(fixedTopHeight, tab == .system ? 110 : 160, "\(tab)")
            XCTAssertGreaterThanOrEqual(frame.minY, 640 - layout.resolvedPanelHeight + 23, "Footer: \(tab) \(frame)")
            let document = try XCTUnwrap(scroll.documentView)
            XCTAssertGreaterThan(document.bounds.height, scroll.contentView.bounds.height, "\(tab)")
            scroll.contentView.scroll(to: NSPoint(x: 0, y: 150))
            scroll.reflectScrolledClipView(scroll.contentView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0, "\(tab)")
            XCTAssertFalse(scroll.hasVerticalScroller, "Unexpected scrollbar while scrolling \(tab)")
            XCTAssertEqual(scroll.convert(scroll.bounds, to: nil).maxY, frame.maxY, accuracy: 0.5, "\(tab)")
            XCTAssertGreaterThanOrEqual(scroll.convert(scroll.bounds, to: nil).minY,
                                        640 - layout.resolvedPanelHeight + 23, "Scrolled footer: \(tab)")
        }

        model.activeMenuTab = .proxy
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let returnedScroll = try self.contentScrollView(in: hosting)
        XCTAssertFalse(returnedScroll.hasVerticalScroller, "Scrollbar reappeared when returning to nodes")
        XCTAssertEqual(returnedScroll.contentView.frame.width, returnedScroll.bounds.width, accuracy: 0.5)
        let localScrollTop = try self.contentScrollView(in: hosting).convert(
            self.contentScrollView(in: hosting).bounds, to: nil).maxY
        let remote = RemoteMachine(name: "Test Router", host: "192.0.2.10")
        machines.machines = [remote]
        machines.activeTargetID = remote.id
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let remoteScroll = try self.contentScrollView(in: hosting)
        XCTAssertTrue(model.isRemoteTarget)
        XCTAssertGreaterThan(remoteScroll.convert(remoteScroll.bounds, to: nil).maxY - localScrollTop, 30)

        let decorationHeight = window.frame.height - hosting.bounds.height
        let windowTop = window.frame.maxY
        let heightSubscription = layout.$resolvedPanelHeight
            .receive(on: RunLoop.main)
            .sink { [weak window] height in
                guard let window else { return }
                window.setFrame(NSRect(x: window.frame.minX, y: windowTop - height - decorationHeight,
                                       width: 360, height: height + decorationHeight), display: true)
            }
        defer { heightSubscription.cancel() }
        layout.resizePanelHeight(to: 480, minimum: 280)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        let dragStart = NSPoint(x: 338, y: 12)
        try self.drag(in: window, from: dragStart, deltaY: 0, deltaX: 80)
        XCTAssertEqual(layout.resolvedPanelHeight, 480, accuracy: 1)
        XCTAssertEqual(hosting.bounds.width, 360, accuracy: 0.5)
        try self.drag(in: window, from: dragStart, deltaY: -80)
        XCTAssertEqual(layout.resolvedPanelHeight, 560, accuracy: 1)
        XCTAssertEqual(hosting.bounds.height, 560, accuracy: 1)
        XCTAssertEqual(window.frame.maxY, windowTop, accuracy: 0.5)
        try self.drag(in: window, from: dragStart, deltaY: -200)
        XCTAssertEqual(layout.resolvedPanelHeight, 640, accuracy: 1)
        try self.drag(in: window, from: NSPoint(x: 338, y: 12), deltaY: 500)
        XCTAssertGreaterThanOrEqual(layout.resolvedPanelHeight, layout.minPanelHeight)
        XCTAssertLessThan(layout.resolvedPanelHeight, 480)
        XCTAssertEqual(hosting.bounds.width, 360, accuracy: 0.5)

        let beforeMove = window.frame
        let handlePoint = NSPoint(x: 180, y: hosting.bounds.height - MenuBarLayoutTokens.panelDragHandleHeight / 2)
        try self.drag(in: window, from: handlePoint, deltaY: -50, deltaX: 80)
        XCTAssertEqual(window.frame.minX, beforeMove.minX + 80, accuracy: 0.5)
        XCTAssertEqual(window.frame.minY, beforeMove.minY, accuracy: 0.5)
        XCTAssertEqual(window.frame.size, beforeMove.size)
        let afterMove = window.frame
        try self.drag(in: window, from: handlePoint, deltaY: 80)
        XCTAssertEqual(window.frame, afterMove, "The top handle must only move horizontally")
        try self.drag(in: window, from: handlePoint, deltaY: 0, deltaX: -screen.frame.width * 2)
        XCTAssertEqual(window.frame.minX, screen.visibleFrame.minX + 8, accuracy: 0.5)
        try self.drag(in: window, from: handlePoint, deltaY: 0, deltaX: screen.frame.width * 2)
        XCTAssertEqual(window.frame.maxX, screen.visibleFrame.maxX - 8, accuracy: 0.5)
        let handle = try XCTUnwrap(self.horizontalDragHandle(in: hosting))
        XCTAssertTrue(handle.accessibilityPerformDecrement())
        XCTAssertEqual(window.frame.maxX, screen.visibleFrame.maxX - 40, accuracy: 0.5)

        heightSubscription.cancel()
        window.orderOut(nil)
        machines.activeTargetID = nil
        try self.exerciseControllerMovement(model: model)

        XCTAssertNil(model.apiClient)
        XCTAssertFalse(model.processManager.isRunning)
    }

    @MainActor
    private func exerciseControllerMovement(model: AppViewModel) throws {
        // Reserve polling slots and skip release checks to keep the window fixture offline. / 占用轮询槽位并跳过版本检查，保持窗口测试离线。
        model.mediumFrequencyTask = Task {}
        model.lowFrequencyTask = Task {}
        model.isPanelPresented = true
        let controller = StatusItemController(appViewModel: model)
        defer { controller.shutdown() }
        model.logsStore.errorLogs = []
        controller.presentPopover(tab: .proxy)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let panel = try XCTUnwrap(NSApplication.shared.windows.first {
            $0 is NSPanel && $0.isVisible && self.horizontalDragHandle(in: $0.contentView) != nil
        })
        defer { panel.close() }
        let beforeMove = panel.frame
        let screen = try XCTUnwrap(panel.screen)
        let deltaX: CGFloat = beforeMove.midX > screen.visibleFrame.midX ? -100 : 100
        try self.drag(in: panel, from: NSPoint(x: 180, y: panel.frame.height - 8), deltaY: -40, deltaX: deltaX)
        let movedX = panel.frame.minX
        XCTAssertEqual(movedX, beforeMove.minX + deltaX, accuracy: 0.5)
        XCTAssertEqual(panel.frame.minY, beforeMove.minY, accuracy: 0.5)
        XCTAssertEqual(panel.frame.size, beforeMove.size)

        // The plain xctest host lacks app resources; run pixel checks with the localized host. / 普通 xctest 宿主缺少应用资源，像素检查使用含本地化资源的宿主。
        let hasLocalizedLabels = model.tr(RootTab.rules.titleKey) != RootTab.rules.titleKey
        let labelBounds = hasLocalizedLabels ? try self.tabLabelInkBounds(in: panel) : nil
        for tab in [RootTab.logs, .system, .proxy] {
            if hasLocalizedLabels {
                let column = try XCTUnwrap(RootTab.allCases.firstIndex(of: tab))
                let point = NSPoint(x: 8 + CGFloat(column) * 68.8 + 34.4, y: panel.frame.height - 122)
                for eventType in [NSEvent.EventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
                    let event = try XCTUnwrap(NSEvent.mouseEvent(
                        with: eventType, location: point, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                        context: nil, eventNumber: 901, clickCount: 1, pressure: 1))
                    NSApplication.shared.sendEvent(event)
                }
            } else {
                model.activeMenuTab = tab
            }
            for interval in [0.01, 0.02, 0.04, 0.2] {
                RunLoop.current.run(until: Date().addingTimeInterval(interval))
                if let labelBounds {
                    XCTAssertEqual(try self.tabLabelInkBounds(in: panel), labelBounds,
                                   "Tab labels must stay fixed throughout the transition to \(tab)")
                }
            }
            XCTAssertEqual(model.activeMenuTab, tab)
            XCTAssertEqual(panel.frame.minX, movedX, accuracy: 0.5, "Position reset after switching to \(tab)")
            XCTAssertEqual(panel.frame.maxY, beforeMove.maxY, accuracy: 0.5)
            XCTAssertEqual(panel.frame.width, 360, accuracy: 0.5)
        }
        try self.drag(in: panel, from: NSPoint(x: 338, y: 12), deltaY: 160, deltaX: 80)
        XCTAssertEqual(panel.frame.minX, movedX, accuracy: 0.5, "Resizing must preserve the dragged position")
        XCTAssertEqual(panel.frame.maxY, beforeMove.maxY, accuracy: 0.5)
        XCTAssertEqual(panel.frame.width, 360, accuracy: 0.5)
        try self.exerciseStatusItemToggle(controller: controller, model: model, panel: panel)
    }

    @MainActor
    private func exerciseStatusItemToggle(controller: StatusItemController, model: AppViewModel, panel: NSWindow) throws {
        func findButton(in view: NSView?) -> NSStatusBarButton? {
            guard let view else { return nil }
            if let button = view as? NSStatusBarButton, button.target as? StatusItemController === controller {
                return button
            }
            return view.subviews.lazy.compactMap { findButton(in: $0) }.first
        }
        let button = try XCTUnwrap(NSApplication.shared.windows.lazy.compactMap { findButton(in: $0.contentView) }.first)
        let anchor = try XCTUnwrap(PanelAnchorContext.resolve(for: button)).anchorFrameOnScreen
        let iconPoint = NSPoint(x: anchor.midX, y: anchor.midY)

        for _ in 0..<2 {
            if !panel.isVisible {
                model.mediumFrequencyTask = Task {}
                model.lowFrequencyTask = Task {}
                model.isPanelPresented = true
                button.performClick(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            XCTAssertTrue(panel.isVisible)
            controller.handleGlobalMouseDown(at: iconPoint)
            XCTAssertTrue(panel.isVisible, "The global mouse-down handler must leave icon clicks to the toggle")
            button.performClick(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            XCTAssertFalse(panel.isVisible, "An icon action must close the visible menu exactly once")
        }

        model.mediumFrequencyTask = Task {}
        model.lowFrequencyTask = Task {}
        model.isPanelPresented = true
        button.performClick(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        let outsidePoint = NSPoint(x: panel.frame.maxX + 32, y: panel.frame.midY)
        controller.handleGlobalMouseDown(at: NSPoint(x: panel.frame.midX, y: panel.frame.midY))
        XCTAssertTrue(panel.isVisible, "Clicks inside the panel must not dismiss it")
        model.isPinned = true
        controller.handleGlobalMouseDown(at: outsidePoint)
        XCTAssertTrue(panel.isVisible, "Outside clicks must not dismiss a pinned menu")
        model.isPinned = false
        controller.handleGlobalMouseDown(at: outsidePoint)
        XCTAssertFalse(panel.isVisible, "Outside clicks must dismiss an unpinned menu")
    }

    @MainActor
    private func tabLabelInkBounds(in panel: NSWindow) throws -> ClosedRange<Int> {
        // Sample an unchanged label while the background crosses it and the window resizes. / 背景滑过且窗口缩放时，采样未切换的标签文字。
        let content = try XCTUnwrap(panel.contentView)
        let rect = NSRect(x: 94, y: content.isFlipped ? 108 : content.bounds.height - 136, width: 36, height: 28)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: rect))
        content.cacheDisplay(in: rect, to: bitmap)
        let isDark = content.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var firstRow: Int?
        var lastRow: Int?
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                if isDark ? brightness > 0.35 : brightness < 0.65 {
                    if firstRow == nil { firstRow = y }
                    lastRow = y
                    break
                }
            }
        }
        return try XCTUnwrap(firstRow, "Tab label disappeared from its row")...XCTUnwrap(lastRow)
    }

    @MainActor
    private func horizontalDragHandle(in view: NSView?) -> PanelHorizontalDragHandle.DragView? {
        guard let view else { return nil }
        if let handle = view as? PanelHorizontalDragHandle.DragView { return handle }
        return view.subviews.lazy.compactMap { self.horizontalDragHandle(in: $0) }.first
    }

    @MainActor
    private func contentScrollView(in view: NSView) throws -> NSScrollView {
        func descendants(_ node: NSView) -> [NSScrollView] {
            let own = (node as? NSScrollView).map { [$0] } ?? []
            return own + node.subviews.flatMap(descendants)
        }
        let scrolls = descendants(view).filter { !$0.isHidden && $0.bounds.height > 50 }
        XCTAssertEqual(scrolls.count, 1)
        return try XCTUnwrap(scrolls.first)
    }

    @MainActor
    private func drag(in window: NSWindow, from start: NSPoint, deltaY: CGFloat, deltaX: CGFloat = 0) throws {
        let screenStart = window.convertPoint(toScreen: start)
        let end = NSPoint(x: screenStart.x + deltaX, y: screenStart.y + deltaY)
        let middle = NSPoint(x: screenStart.x + deltaX / 2, y: screenStart.y + deltaY / 2)
        let events: [(NSEvent.EventType, NSPoint)] = [
            (.leftMouseDown, screenStart), (.leftMouseDragged, middle), (.leftMouseDragged, end), (.leftMouseUp, end),
        ]
        for (index, event) in events.enumerated() {
            let mouse = try XCTUnwrap(NSEvent.mouseEvent(
                with: event.0, location: window.convertPoint(fromScreen: event.1), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 100 + index, clickCount: 1, pressure: 1))
            NSApplication.shared.sendEvent(mouse)
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
