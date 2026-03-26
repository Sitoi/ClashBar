import Foundation

@MainActor
struct GrantTunPermissionsUseCase {
    private let repository: any TunPermissionRepository

    init(repository: any TunPermissionRepository) {
        self.repository = repository
    }

    func execute(binaryPath: String) async throws {
        try await self.repository.grantPermissions(binaryPath: binaryPath)
    }
}
