import Foundation

enum SystemFeedbackKind {
    case error
    case warning
    case success
}

struct SystemFeedbackState: Equatable {
    let message: String
    let kind: SystemFeedbackKind
    let symbol: String
}

@MainActor
enum SystemTabViewModel {
    static func maintenanceActionEnabled(session: AppSession) -> Bool {
        session.isRemoteTarget || session.coreRepository.isRunning || session.statusText.lowercased() == "running"
    }

    static func feedbackState(session: AppSession) -> SystemFeedbackState? {
        if let error = session.settingsErrorMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: error,
                kind: .error,
                symbol: "exclamationmark.triangle.fill")
        }

        if let launchError = session.launchAtLoginErrorMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: launchError,
                kind: .warning,
                symbol: "exclamationmark.circle.fill")
        }

        if let saved = session.settingsSavedMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: saved,
                kind: .success,
                symbol: "checkmark.circle.fill")
        }

        return nil
    }
}
