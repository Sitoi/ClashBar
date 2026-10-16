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
        onPayload: @escaping (Data) async -> Void,
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
        onPayload: @escaping (Data) async -> Void,
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

                while !Task.isCancelled {
                    let delay = self.shouldReconnect()
                        ? self.nextReconnectDelayNanoseconds(for: key)
                        : self.maxDelayNanoseconds
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch {
                        return
                    }
                    if Task.isCancelled {
                        return
                    }
                    if self.shouldReconnect() {
                        restart()
                        return
                    }
                }
                return
            }

            guard let payload = normalizePayload(message) else { continue }
            self.markPayloadReceived(for: key)
            await onPayload(payload)
        }
    }

    static func normalizeWebSocketPayload(_ message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case let .data(data):
            guard !data.isEmpty else { return nil }
            return data
        case let .string(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "null", trimmed != "{}" else { return nil }
            return Data(trimmed.utf8)
        @unknown default:
            return nil
        }
    }

    private func nextReconnectDelayNanoseconds(for key: String) -> UInt64 {
        let attempt = max(0, self.streamReconnectAttempts[key] ?? 0)
        let cappedShift = min(attempt, 3)
        let seconds = min(8, 1 << cappedShift)
        self.streamReconnectAttempts[key] = min(attempt + 1, 8)

        let base = UInt64(seconds) * self.baseDelayNanoseconds
        let jittered = UInt64(Double(base) * Double.random(in: 0.85...1.15))
        return min(self.maxDelayNanoseconds, max(self.baseDelayNanoseconds, jittered))
    }

    private func markPayloadReceived(for key: String) {
        self.streamReconnectAttempts[key] = 0
    }

    private func shouldLogDisconnect(key: String, message: String) -> Bool {
        let now = Date()
        let lastAt = self.streamLastDisconnectLogAt[key]
        let lastMessage = self.streamLastDisconnectLogMessage[key]

        let shouldEmit: Bool
        if let lastAt, let lastMessage {
            let withinThrottle = now.timeIntervalSince(lastAt) < self.disconnectLogThrottleInterval
            shouldEmit = !(withinThrottle && lastMessage == message)
        } else {
            shouldEmit = true
        }

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
