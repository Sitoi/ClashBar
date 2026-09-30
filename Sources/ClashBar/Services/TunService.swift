import Foundation

enum TunPermissionServiceError: LocalizedError {
    case coreBinaryNotFound
    case coreBinaryNotExecutable
    case permissionMissing
    case authorizationCancelled
    case authorizationFailed(String)
    case permissionVerificationFailed

    var errorDescription: String? {
        switch self {
        case .coreBinaryNotFound:
            "mihomo binary not found."
        case .coreBinaryNotExecutable:
            "mihomo binary is not executable."
        case .permissionMissing:
            "mihomo binary does not have required TUN privileges."
        case .authorizationCancelled:
            "Administrator authorization was cancelled."
        case let .authorizationFailed(message):
            "Failed to authorize TUN privileges: \(message)"
        case .permissionVerificationFailed:
            "TUN privileges were not applied successfully."
        }
    }
}

struct TunPermissionService {
    func hasRequiredPermissions(binaryPath: String) -> Bool {
        let normalizedPath = binaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else { return false }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: normalizedPath) else { return false }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: normalizedPath)
            let ownerID = (attributes[.ownerAccountID] as? NSNumber)?.intValue
            let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0

            let hasRootOwner = ownerID == 0
            let hasSetuid = (mode & 0o4000) != 0
            let ownerExecutable = (mode & 0o100) != 0
            return hasRootOwner && hasSetuid && ownerExecutable
        } catch {
            return false
        }
    }

    func grantPermissions(binaryPath: String) async throws {
        let resolvedBinaryPath = try validateBinaryPath(binaryPath)
        try await Task.detached(priority: .userInitiated) {
            try self.grantPermissionsSynchronously(binaryPath: resolvedBinaryPath)
        }.value
    }

    func validateCurrentPermissions(binaryPath: String) throws {
        let resolvedBinaryPath = try validateBinaryPath(binaryPath)
        guard self.hasRequiredPermissions(binaryPath: resolvedBinaryPath) else {
            throw TunPermissionServiceError.permissionMissing
        }
    }

    private func validateBinaryPath(_ binaryPath: String) throws -> String {
        let resolvedBinaryPath = binaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedBinaryPath.isEmpty else {
            throw TunPermissionServiceError.coreBinaryNotFound
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: resolvedBinaryPath) else {
            throw TunPermissionServiceError.coreBinaryNotFound
        }
        guard fileManager.isExecutableFile(atPath: resolvedBinaryPath) else {
            throw TunPermissionServiceError.coreBinaryNotExecutable
        }
        return resolvedBinaryPath
    }

    private func grantPermissionsSynchronously(binaryPath: String) throws {
        let escapedPath = AdministratorShell.shellQuoted(binaryPath)
        try AdministratorShell.run(
            "/usr/sbin/chown root:admin \(escapedPath) && /bin/chmod u+s \(escapedPath)",
            cancelled: TunPermissionServiceError.authorizationCancelled,
            failed: TunPermissionServiceError.authorizationFailed)

        guard self.hasRequiredPermissions(binaryPath: binaryPath) else {
            throw TunPermissionServiceError.permissionVerificationFailed
        }
    }
}
