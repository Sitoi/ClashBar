import Foundation

@MainActor
protocol TunPermissionRepository: AnyObject {
    func hasRequiredPermissions(binaryPath: String) -> Bool
    func validateCurrentPermissions(binaryPath: String) throws
    func grantPermissions(binaryPath: String) async throws
}
