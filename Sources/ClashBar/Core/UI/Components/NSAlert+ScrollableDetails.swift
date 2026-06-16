import AppKit

extension NSAlert {
    /// Presents long text in a fixed-size, scrollable accessory view instead of
    /// `informativeText`. Because the accessory keeps a constant frame, the alert
    /// window never grows past the screen and its buttons always stay reachable —
    /// the core failure mode when feeding raw `mihomo -t` output into an alert.
    ///
    /// Uses an explicit frame (no Auto Layout) on purpose: the previous attempt
    /// computed a dynamic height and let Auto Layout drive the accessory, which
    /// overlapped the buttons in compact windows. A constant frame avoids that.
    func setScrollableDetails(
        _ text: String,
        width: CGFloat = 440,
        height: CGFloat = 200,
        maxCharacters: Int = 20000)
    {
        // Cap pathological inputs so layout stays cheap; the full text is still
        // available via the alert's "Copy Details" action.
        let clipped = text.count > maxCharacters
            ? String(text.prefix(maxCharacters)) + "\n…"
            : text

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.string = clipped

        scrollView.documentView = textView
        self.accessoryView = scrollView
    }
}
