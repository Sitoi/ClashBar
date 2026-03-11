import Foundation

@MainActor
extension AppState {
    func showPanelFeedback(
        _ message: String,
        style: PanelFeedbackStyle = .info,
        symbol: String? = nil,
        durationNanoseconds: UInt64 = 1_800_000_000)
    {
        guard let trimmedMessage = message.trimmedNonEmpty else { return }

        let feedback = PanelFeedback(
            message: trimmedMessage,
            symbol: symbol ?? self.defaultPanelFeedbackSymbol(for: style),
            style: style)

        self.panelFeedbackClearTask?.cancel()
        self.panelFeedback = feedback

        self.panelFeedbackClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: durationNanoseconds)
            } catch {
                return
            }

            guard let self else { return }
            if self.panelFeedback == feedback {
                self.panelFeedback = nil
            }
        }
    }

    private func defaultPanelFeedbackSymbol(for style: PanelFeedbackStyle) -> String {
        switch style {
        case .info:
            "info.circle.fill"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }
}
