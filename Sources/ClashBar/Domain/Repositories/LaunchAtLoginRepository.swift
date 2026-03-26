import Foundation

@MainActor
protocol LaunchAtLoginRepository: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}
