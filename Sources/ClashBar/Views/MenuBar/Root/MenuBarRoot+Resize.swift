import AppKit
import SwiftUI

extension MenuBarRootView {
    var panelHeightResizeHandle: some View {
        Path { path in
            for inset in [CGFloat(2), 6, 10] {
                path.move(to: CGPoint(x: inset, y: 12))
                path.addLine(to: CGPoint(x: 12, y: inset))
            }
        }
        .stroke(self.nativeSecondaryLabel, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        .frame(width: 12, height: 12)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .overlay {
            PanelHeightDragArea(
                onDrag: { translation in
                    if self.resizeStartHeight == nil {
                        self.resizeStartHeight = self.resolvedPanelHeight
                    }
                    self.popoverLayoutModel.resizePanelHeight(
                        to: (self.resizeStartHeight ?? self.resolvedPanelHeight) + translation,
                        minimum: self.minimumPanelHeight)
                },
                onEnd: { self.resizeStartHeight = nil })
                .accessibilityHidden(true)
        }
        .help(self.tr("ui.footer.resize_height"))
        .accessibilityElement()
        .accessibilityLabel(self.tr("ui.footer.resize_height"))
        .accessibilityValue("\(Int(self.resolvedPanelHeight))")
        .accessibilityAdjustableAction { direction in
            let delta: CGFloat
            switch direction {
            case .increment: delta = 32
            case .decrement: delta = -32
            @unknown default: return
            }
            self.popoverLayoutModel.resizePanelHeight(
                to: self.resolvedPanelHeight + delta,
                minimum: self.minimumPanelHeight)
        }
    }
}

private struct PanelHeightDragArea: NSViewRepresentable {
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.onDrag = self.onDrag
        view.onEnd = self.onEnd
    }

    final class DragView: NSView {
        var onDrag: ((CGFloat) -> Void)?
        var onEnd: (() -> Void)?
        private var startScreenY: CGFloat?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            self.addCursorRect(self.bounds, cursor: .resizeUpDown)
        }

        override func mouseDown(with event: NSEvent) {
            self.startScreenY = self.window?.convertPoint(toScreen: event.locationInWindow).y
            self.onDrag?(0)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let startScreenY = self.startScreenY, let window = self.window else { return }
            // Screen coordinates stay stable while the panel grows. / 屏幕坐标不随面板缩放移动。
            self.onDrag?(startScreenY - window.convertPoint(toScreen: event.locationInWindow).y)
        }

        override func mouseUp(with event: NSEvent) {
            self.mouseDragged(with: event)
            self.startScreenY = nil
            self.onEnd?()
        }
    }
}
