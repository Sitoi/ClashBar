import Foundation

@MainActor
final class StreamCoordinator {
    var streamReceiveTasks: [String: Task<Void, Never>] = [:]
    var streamWebSocketTasks: [String: URLSessionWebSocketTask] = [:]
    var streamReconnectAttempts: [String: Int] = [:]
    var streamLastDisconnectLogAt: [String: Date] = [:]
    var streamLastDisconnectLogMessage: [String: String] = [:]

    let baseDelayNanoseconds: UInt64
    let maxDelayNanoseconds: UInt64
    let disconnectLogThrottleInterval: TimeInterval

    var shouldReconnect: () -> Bool = { false }
    var onDisconnect: (String, String) -> Void = { _, _ in }
    var onStartError: (String, Error) -> Void = { _, _ in }

    init(
        baseDelayNanoseconds: UInt64 = 1_000_000_000,
        maxDelayNanoseconds: UInt64 = 8_000_000_000,
        disconnectLogThrottleInterval: TimeInterval = 2)
    {
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.maxDelayNanoseconds = maxDelayNanoseconds
        self.disconnectLogThrottleInterval = disconnectLogThrottleInterval
    }

    func start(
        key: String,
        makeWebSocket: @escaping () throws -> URLSessionWebSocketTask,
        onPayload: @escaping (Data) -> Void,
        normalizePayload: @escaping (URLSessionWebSocketTask.Message) -> Data?)
    {
        self.cancel(key: key, resetReconnectState: false)

        do {
            let ws = try makeWebSocket()
            self.streamWebSocketTasks[key] = ws
            ws.resume()

            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.receiveLoop(
                    key: key,
                    onPayload: onPayload,
                    normalizePayload: normalizePayload,
                    restart: { [weak self] in
                        self?.start(
                            key: key,
                            makeWebSocket: makeWebSocket,
                            onPayload: onPayload,
                            normalizePayload: normalizePayload)
                    })
            }
            self.streamReceiveTasks[key] = task
        } catch {
            if !(error is CancellationError) {
                self.onStartError(key, error)
            }
        }
    }

    func cancel(key: String, resetReconnectState: Bool = true) {
        self.streamReceiveTasks[key]?.cancel()
        self.streamWebSocketTasks[key]?.cancel(with: .goingAway, reason: nil)
        self.streamReceiveTasks[key] = nil
        self.streamWebSocketTasks[key] = nil
        if resetReconnectState {
            self.clearReconnectState(for: key)
        }
    }

    func cancelAll() {
        for key in self.streamReceiveTasks.keys {
            self.cancel(key: key)
        }
    }

    func isActive(key: String) -> Bool {
        self.streamWebSocketTasks[key] != nil
    }

    func webSocketTask(for key: String) -> URLSessionWebSocketTask? {
        self.streamWebSocketTasks[key]
    }

    private func receiveLoop(
        key: String,
        onPayload: @escaping (Data) -> Void,
        normalizePayload: @escaping (URLSessionWebSocketTask.Message) -> Data?,
        restart: @escaping () -> Void) async
    {
        while !Task.isCancelled {
            guard let ws = streamWebSocketTasks[key] else { return }

            let message: URLSessionWebSocketTask.Message
            do {
                message = try await ws.receive()
            } catch {
                if Task.isCancelled {
                    return
                }

                let errorMessage = error.localizedDescription
                if self.shouldLogDisconnect(key: key, message: errorMessage) {
                    self.onDisconnect(key, errorMessage)
                }
                self.streamWebSocketTasks[key]?.cancel(with: .goingAway, reason: nil)
                self.streamWebSocketTasks[key] = nil

                guard self.shouldReconnect() else { return }
                do {
                    try await Task.sleep(nanoseconds: self.nextReconnectDelayNanoseconds(for: key))
                } catch {
                    return
                }
                if Task.isCancelled {
                    return
                }
                guard self.shouldReconnect() else { return }
                restart()
                return
            }

            guard let payload = normalizePayload(message) else { continue }
            self.markPayloadReceived(for: key)
            onPayload(payload)
        }
    }

    private func nextReconnectDelayNanoseconds(for key: String) -> UInt64 {
        let attempt = self.streamReconnectAttempts[key] ?? 0
        let result = ComputeNextStreamReconnectDelayUseCase().execute(
            currentAttempt: attempt,
            baseDelayNanoseconds: self.baseDelayNanoseconds,
            maxDelayNanoseconds: self.maxDelayNanoseconds,
            jitter: Double.random(in: 0.85...1.15))
        self.streamReconnectAttempts[key] = result.nextAttempt
        return result.delayNanoseconds
    }

    private func markPayloadReceived(for key: String) {
        self.streamReconnectAttempts[key] = 0
    }

    private func shouldLogDisconnect(key: String, message: String) -> Bool {
        let now = Date()
        let lastAt = self.streamLastDisconnectLogAt[key]
        let lastMessage = self.streamLastDisconnectLogMessage[key]

        let shouldEmit = ShouldEmitStreamDisconnectLogUseCase().execute(
            now: now,
            lastLoggedAt: lastAt,
            lastLoggedMessage: lastMessage,
            currentMessage: message,
            throttleInterval: self.disconnectLogThrottleInterval)

        if shouldEmit {
            self.streamLastDisconnectLogAt[key] = now
            self.streamLastDisconnectLogMessage[key] = message
        }
        return shouldEmit
    }

    func clearReconnectState(for key: String) {
        self.streamReconnectAttempts.removeValue(forKey: key)
        self.streamLastDisconnectLogAt.removeValue(forKey: key)
        self.streamLastDisconnectLogMessage.removeValue(forKey: key)
    }
}
