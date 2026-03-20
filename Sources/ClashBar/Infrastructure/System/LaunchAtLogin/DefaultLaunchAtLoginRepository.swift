import Foundation

@MainActor
final class DefaultLaunchAtLoginRepository: LaunchAtLoginRepository {
    private let service: AppLaunchService

    init(service: AppLaunchService) {
        self.service = service
    }

    var isEnabled: Bool {
        self.service.isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        try self.service.setEnabled(enabled)
    }
}
