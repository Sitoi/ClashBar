import Foundation

@MainActor
protocol ClipboardRepository: AnyObject {
    func copy(_ text: String)
}
