import Foundation

@MainActor
struct ReadLaunchAtLoginEnabledUseCase {
    private let repository: any LaunchAtLoginRepository

    init(repository: any LaunchAtLoginRepository) {
        self.repository = repository
    }

    func execute() -> Bool {
        self.repository.isEnabled
    }
}
