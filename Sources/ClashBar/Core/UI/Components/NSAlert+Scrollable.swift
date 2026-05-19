import AppKit

extension NSAlert {
    /// Sets the text as a dynamically sized, scrollable accessory view instead of standard informativeText.
    /// This prevents the alert window from growing taller than the screen when displaying long text (e.g., error logs).
    func setScrollableInformativeText(_ text: String, width: CGFloat = 400, maxHeight: CGFloat = 300) {
        // Clear default informative text to prevent duplicate display and unbound height
        self.informativeText = ""
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        
        textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        textView.textColor = NSColor.labelColor
        textView.string = text
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        
        let requiredHeight = usedRect.height
        let height = min(requiredHeight, maxHeight)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        textView.frame = NSRect(x: 0, y: 0, width: width, height: requiredHeight)
        scrollView.documentView = textView
        
        self.accessoryView = scrollView
    }
}
