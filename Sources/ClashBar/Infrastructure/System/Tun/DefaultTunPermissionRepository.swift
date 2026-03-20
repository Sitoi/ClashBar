import Foundation

@MainActor
final class DefaultTunPermissionRepository: TunPermissionRepository {
    private let service: TunPermissionService

    init(service: TunPermissionService) {
        self.service = service
    }

    func hasRequiredPermissions(binaryPath: String) -> Bool {
        self.service.hasRequiredPermissions(binaryPath: binaryPath)
    }

    func validateCurrentPermissions(binaryPath: String) throws {
        try self.service.validateCurrentPermissions(binaryPath: binaryPath)
    }

    func grantPermissions(binaryPath: String) async throws {
        try await self.service.grantPermissions(binaryPath: binaryPath)
    }
}
