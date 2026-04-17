import Foundation

struct StreamReconnectDelayResult {
    let delayNanoseconds: UInt64
    let nextAttempt: Int
}

struct ComputeNextStreamReconnectDelayUseCase {
    /// Pure function: given a prior attempt count, base/cap bounds, and a
    /// precomputed jitter multiplier, returns the next delay and attempt.
    /// Jitter is injected to keep this UseCase deterministic and testable;
    /// callers (e.g. `StreamCoordinator`) supply `Double.random(in:)` at the
    /// edge.
    func execute(
        currentAttempt: Int?,
        baseDelayNanoseconds: UInt64,
        maxDelayNanoseconds: UInt64,
        jitter: Double) -> StreamReconnectDelayResult
    {
        let attempt = max(0, currentAttempt ?? 0)
        let cappedShift = min(attempt, 3)
        let seconds = min(8, 1 << cappedShift)
        let nextAttempt = min(attempt + 1, 8)

        let base = UInt64(seconds) * baseDelayNanoseconds
        let jittered = UInt64(Double(base) * jitter)
        let delay = min(maxDelayNanoseconds, max(baseDelayNanoseconds, jittered))

        return StreamReconnectDelayResult(
            delayNanoseconds: delay,
            nextAttempt: nextAttempt)
    }
}
