import AppKit
import SwiftUI
import XCTest
@testable import ClashBar

final class AttachedPopoverMenuTests: XCTestCase {
    @MainActor private var nextMouseEventNumber = 0

    @MainActor
    func testRepeatedClickClosesMenuWithoutRefreshingAndNextClickReopens() throws {
        weak var removedPanel: NSWindow?
        try autoreleasepool {
            let app = NSApplication.shared
            guard let screen = NSScreen.main else {
                throw XCTSkip("Requires a macOS window server")
            }
            app.setActivationPolicy(.accessory)
            app.activate(ignoringOtherApps: true)

            var presentations = 0
            var selections = 0
            let menu = AttachedPopoverMenu(
                expandAnchor: false,
                placement: .below,
                opensOnHover: false,
                onWillPresent: { presentations += 1 },
                label: { _ in Text("Office Mac").frame(width: 180, height: 24) },
                content: { dismiss in
                    AttachedPopoverMenuItem(
                        title: "Local",
                        subtitle: "127.0.0.1:9090",
                        leadingSymbol: "desktopcomputer")
                    {
                        selections += 1
                        dismiss()
                    }
                    AttachedPopoverMenuItem(
                        title: "Office Mac",
                        subtitle: "192.0.2.10:9090",
                        leadingSymbol: "network",
                        selected: true,
                        selectionIndicatorPlacement: .trailing,
                        action: dismiss)
                })
            let window = NSWindow(
                contentRect: NSRect(x: screen.visibleFrame.minX + 100, y: screen.visibleFrame.minY + 100,
                                    width: 400, height: 320),
                styleMask: [.titled],
                backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            let root = VStack(alignment: .leading, spacing: 8) {
                Text("ClashBar").frame(height: 20)
                menu
                Spacer()
            }
            .padding(20)
            .frame(width: 400, height: 320, alignment: .topLeading)
            window.contentView = NSHostingView(rootView: root)
            window.makeKeyAndOrderFront(nil)
            defer {
                window.close()
                for panel in app.windows where panel is NSPanel {
                    panel.orderOut(nil)
                }
            }
            window.contentView?.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            weak var releasedPanel: NSWindow?
            try autoreleasepool {
                let anchor = NSPoint(x: 100, y: 260)
                try self.click(in: window, at: anchor)
                self.waitUntil { app.windows.contains { $0 is NSPanel && $0.isVisible } }
                XCTAssertEqual(presentations, 1)
                let firstPanel = try XCTUnwrap(app.windows.first { $0 is NSPanel && $0.isVisible })
                let anchorBottom = window.convertPoint(toScreen: NSPoint(x: 20, y: 248))
                XCTAssertEqual(firstPanel.frame.minX, anchorBottom.x, accuracy: 1)
                XCTAssertEqual(firstPanel.frame.maxY, anchorBottom.y - 4, accuracy: 1)

                try self.click(in: window, at: anchor)
                self.waitUntil { !app.windows.contains { $0 is NSPanel && $0.isVisible } }
                XCTAssertFalse(app.windows.contains { $0 is NSPanel && $0.isVisible })
                XCTAssertEqual(presentations, 1)

                try self.click(in: window, at: anchor)
                self.waitUntil { app.windows.contains { $0 is NSPanel && $0.isVisible } }
                XCTAssertTrue(app.windows.contains { $0 is NSPanel && $0.isVisible })
                XCTAssertEqual(presentations, 2)

                let panel = try XCTUnwrap(app.windows.first { $0 is NSPanel && $0.isVisible })
                try self.click(in: panel, at: NSPoint(x: 40, y: panel.contentLayoutRect.height - 20))
                self.waitUntil { !panel.isVisible }
                XCTAssertFalse(panel.isVisible)
                XCTAssertEqual(selections, 1)
                XCTAssertEqual(presentations, 2)

                try self.click(in: window, at: anchor)
                self.waitUntil { app.windows.contains { $0 is NSPanel && $0.isVisible } }
                XCTAssertTrue(app.windows.contains { $0 is NSPanel && $0.isVisible })
                XCTAssertEqual(presentations, 3)
                let openedPanel = try XCTUnwrap(app.windows.first { $0 is NSPanel && $0.isVisible })
                releasedPanel = openedPanel
                try self.click(in: window, at: anchor)
            }
            self.waitUntil { releasedPanel == nil }
            XCTAssertNil(releasedPanel, "Closing the menu must release its native window")

            try autoreleasepool {
                try self.click(in: window, at: NSPoint(x: 100, y: 260))
                self.waitUntil { app.windows.contains { $0 is NSPanel && $0.isVisible } }
                removedPanel = try XCTUnwrap(app.windows.first { $0 is NSPanel && $0.isVisible })
                window.contentView = nil
            }
            self.waitUntil { removedPanel?.isVisible != true }
            XCTAssertFalse(removedPanel?.isVisible ?? false)
        }
        self.waitUntil { removedPanel == nil }
        XCTAssertNil(removedPanel, "Removing an open menu's anchor must release its window")
    }

    @MainActor
    private func click(in window: NSWindow, at point: NSPoint) throws {
        // Match the application's per-event autorelease lifetime. / 模拟应用每次事件结束后的自动释放。
        try autoreleasepool {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                self.nextMouseEventNumber += 1
                let event = try XCTUnwrap(NSEvent.mouseEvent(
                    with: type,
                    location: point,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: self.nextMouseEventNumber,
                    clickCount: 1,
                    pressure: 1))
                NSApplication.shared.sendEvent(event)
            }
        }
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        var completed = false
        repeat {
            autoreleasepool {
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
                completed = condition()
            }
        } while !completed && Date() < deadline
    }
}
