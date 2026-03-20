import AppKit
import Foundation

@MainActor
final class PasteboardClipboardRepository: ClipboardRepository {
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
