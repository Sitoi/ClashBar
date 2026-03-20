import Foundation

@MainActor
extension AppSession {
    private var readLaunchAtLoginEnabledUseCase: ReadLaunchAtLoginEnabledUseCase {
        ReadLaunchAtLoginEnabledUseCase(repository: self.launchAtLoginRepository)
    }

    private var setLaunchAtLoginEnabledUseCase: SetLaunchAtLoginEnabledUseCase {
        SetLaunchAtLoginEnabledUseCase(repository: self.launchAtLoginRepository)
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = self.readLaunchAtLoginEnabledUseCase.execute()
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginErrorMessage = nil

        do {
            launchAtLoginEnabled = try self.setLaunchAtLoginEnabledUseCase.execute(enabled)
        } catch {
            launchAtLoginEnabled = self.readLaunchAtLoginEnabledUseCase.execute()
            launchAtLoginErrorMessage = self.launchAtLoginMessage(for: error)
            appendLog(level: "error", message: tr("log.launch_at_login.toggle_failed", error.localizedDescription))
        }
    }

    private func launchAtLoginMessage(for error: Error) -> String {
        guard let launchError = error as? AppLaunchServiceError else {
            return error.localizedDescription
        }

        switch launchError {
        case .unsupportedEnvironment:
            return tr("app.launch_at_login.error.unsupported_environment")
        case .requiresApproval:
            return tr("app.launch_at_login.error.requires_approval")
        case let .registrationFailed(message):
            return tr("app.launch_at_login.error.register_failed", message)
        case let .unregistrationFailed(message):
            return tr("app.launch_at_login.error.unregister_failed", message)
        }
    }
}
