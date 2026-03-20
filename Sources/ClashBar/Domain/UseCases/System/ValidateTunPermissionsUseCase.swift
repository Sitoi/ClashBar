import Foundation

@MainActor
struct ValidateTunPermissionsUseCase {
    private let repository: any TunPermissionRepository

    init(repository: any TunPermissionRepository) {
        self.repository = repository
    }

    func execute(binaryPath: String) throws {
        try self.repository.validateCurrentPermissions(binaryPath: binaryPath)
    }
}
