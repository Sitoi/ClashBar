import AppKit
import SwiftUI

struct PanelHorizontalDragHandle: NSViewRepresentable {
    let label: String

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.focusRingType = .none
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.slider)
        view.setAccessibilityOrientation(.horizontal)
        view.setAccessibilityMinValue(0)
        view.setAccessibilityMaxValue(100)
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.toolTip = self.label
        view.setAccessibilityLabel(self.label)
    }

    final class DragView: NSView {
        private var grabOffsetX: CGFloat?

        override var acceptsFirstResponder: Bool { true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            self.addCursorRect(self.bounds, cursor: .openHand)
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.secondaryLabelColor.setFill()
            let bar = NSRect(x: self.bounds.midX - 18, y: self.bounds.midY - 1.5, width: 36, height: 3)
            NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
        }

        override func mouseDown(with event: NSEvent) {
            guard let window = self.window else { return }
            window.makeFirstResponder(self)
            self.grabOffsetX = window.convertPoint(toScreen: event.locationInWindow).x - window.frame.minX
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window = self.window, let grabOffsetX = self.grabOffsetX else { return }
            // Screen coordinates avoid drift as the window moves. / 屏幕坐标避免窗口移动造成拖动偏移。
            self.movePanel(to: window.convertPoint(toScreen: event.locationInWindow).x - grabOffsetX)
        }

        override func mouseUp(with event: NSEvent) {
            self.mouseDragged(with: event)
            self.grabOffsetX = nil
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            self.grabOffsetX = nil
            super.viewWillMove(toWindow: newWindow)
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: _ = self.accessibilityPerformDecrement()
            case 124: _ = self.accessibilityPerformIncrement()
            default: super.keyDown(with: event)
            }
        }

        override func accessibilityValue() -> Any? {
            guard let window = self.window, let screen = window.screen else { return 0 }
            let available = screen.visibleFrame.width - window.frame.width - MenuBarLayoutTokens.space8 * 2
            guard available > 0 else { return 0 }
            let offset = window.frame.minX - screen.visibleFrame.minX - MenuBarLayoutTokens.space8
            return Int((min(1, max(0, offset / available)) * 100).rounded())
        }

        override func accessibilityPerformIncrement() -> Bool {
            guard let window = self.window else { return false }
            return self.movePanel(to: window.frame.minX + 32)
        }

        override func accessibilityPerformDecrement() -> Bool {
            guard let window = self.window else { return false }
            return self.movePanel(to: window.frame.minX - 32)
        }

        @discardableResult
        private func movePanel(to proposedX: CGFloat) -> Bool {
            guard proposedX.isFinite, let window = self.window, let screen = window.screen else { return false }
            let originX = PanelGeometry.clampedHorizontalOrigin(
                proposedX, panelWidth: window.frame.width, visibleFrame: screen.visibleFrame,
                padding: MenuBarLayoutTokens.space8)
            guard abs(window.frame.minX - originX) > 0.5 else { return true }
            window.setFrameOrigin(NSPoint(x: originX, y: window.frame.minY))
            NSAccessibility.post(element: self, notification: .valueChanged)
            return true
        }
    }
}
