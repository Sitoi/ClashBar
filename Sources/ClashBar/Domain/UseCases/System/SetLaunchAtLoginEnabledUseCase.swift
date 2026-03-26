import Foundation

@MainActor
struct SetLaunchAtLoginEnabledUseCase {
    private let repository: any LaunchAtLoginRepository

    init(repository: any LaunchAtLoginRepository) {
        self.repository = repository
    }

    func execute(_ enabled: Bool) throws -> Bool {
        try self.repository.setEnabled(enabled)
        return self.repository.isEnabled
    }
}
