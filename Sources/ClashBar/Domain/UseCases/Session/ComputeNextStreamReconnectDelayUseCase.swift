import Foundation

struct StreamReconnectDelayResult {
    let delayNanoseconds: UInt64
    let nextAttempt: Int
}

struct ComputeNextStreamReconnectDelayUseCase {
    func execute(
        currentAttempt: Int?,
        baseDelayNanoseconds: UInt64,
        maxDelayNanoseconds: UInt64) -> StreamReconnectDelayResult
    {
        let attempt = max(0, currentAttempt ?? 0)
        let cappedShift = min(attempt, 3)
        let seconds = min(8, 1 << cappedShift)
        let nextAttempt = min(attempt + 1, 8)

        let jitter = Double.random(in: 0.85...1.15)
        let base = UInt64(seconds) * baseDelayNanoseconds
        let jittered = UInt64(Double(base) * jitter)
        let delay = min(maxDelayNanoseconds, max(baseDelayNanoseconds, jittered))

        return StreamReconnectDelayResult(
            delayNanoseconds: delay,
            nextAttempt: nextAttempt)
    }
}
