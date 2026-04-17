import Foundation

struct ShouldEmitStreamDisconnectLogUseCase {
    func execute(
        now: Date,
        lastLoggedAt: Date?,
        lastLoggedMessage: String?,
        currentMessage: String,
        throttleInterval: TimeInterval) -> Bool
    {
        if let lastLoggedAt, let lastLoggedMessage {
            let withinThrottle = now.timeIntervalSince(lastLoggedAt) < throttleInterval
            return !(withinThrottle && lastLoggedMessage == currentMessage)
        }

        return true
    }
}
