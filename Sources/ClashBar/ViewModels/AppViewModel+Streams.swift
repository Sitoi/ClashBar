import Foundation

@MainActor
extension AppViewModel {
    private var normalizeWebSocketPayloadUseCase: NormalizeWebSocketPayloadUseCase {
        NormalizeWebSocketPayloadUseCase()
    }

    private var decodeStreamLogPayloadUseCase: DecodeStreamLogPayloadUseCase {
        DecodeStreamLogPayloadUseCase()
    }

    enum StreamKind: CaseIterable, Hashable {
        case traffic
        case memory
        case connections
        case logs

        var key: String {
            switch self {
            case .traffic: "traffic"
            case .memory: "memory"
            case .connections: "connections"
            case .logs: "logs"
            }
        }

        var label: String {
            switch self {
            case .traffic: "app.stream.label.traffic"
            case .memory: "app.stream.label.memory"
            case .connections: "app.stream.label.connections"
            case .logs: "app.stream.label.logs"
            }
        }
    }

    func configureStreamCoordinator() {
        streamCoordinator.shouldReconnect = { [weak self] in
            guard let self else { return false }
            // Safety net: never reconnect while the network-managed stop is in
            // progress. The stop task cancels polling immediately, but this guard
            // covers any race where a stream error fires before cancellation lands.
            if self.autoManageCoreOnNetworkChangeEnabled, self.networkReachabilityStatus == .offline {
                return false
            }
            return self.isRemoteTarget || self.coreRepository.isRunning
        }
        streamCoordinator.onDisconnect = { [weak self] key, message in
            guard let self else { return }
            let label = StreamKind.allCases.first(where: { $0.key == key })?.label ?? key
            self.appendLog(
                level: "error", message: tr("log.stream.disconnected", tr(label), message))
        }
        streamCoordinator.onStartError = { [weak self] key, error in
            guard let self else { return }
            let label = StreamKind.allCases.first(where: { $0.key == key })?.label ?? key
            self.appendLog(
                level: "error",
                message: tr("log.stream.start_failed", tr(label), error.localizedDescription))
        }
    }

    func startStream(
        kind: StreamKind,
        preserveReconnectState: Bool = false,
        makeWebSocket: @escaping (MihomoAPIService) throws -> URLSessionWebSocketTask,
        onPayload: @escaping (Data) -> Void)
    {
        // Domain-specific side effects on cancel
        if kind == .connections { currentConnectionsStreamIntervalMilliseconds = nil }
        if kind == .logs { currentLogsStreamLevel = nil }
        if kind == .traffic { self.resetPendingTrafficSnapshotState() }

        if !preserveReconnectState {
            streamCoordinator.clearReconnectState(for: kind.key)
        }

        streamCoordinator.start(
            key: kind.key,
            makeWebSocket: { [weak self] in
                guard let self else { throw CancellationError() }
                let client = try self.clientOrThrow()
                return try makeWebSocket(client)
            },
            onPayload: onPayload,
            normalizePayload: { message in
                NormalizeWebSocketPayloadUseCase().execute(message: message)
            })
    }

    func cancelStream(_ kind: StreamKind, resetReconnectState: Bool = true) {
        streamCoordinator.cancel(key: kind.key, resetReconnectState: resetReconnectState)
        if kind == .connections { currentConnectionsStreamIntervalMilliseconds = nil }
        if kind == .logs { currentLogsStreamLevel = nil }
        if kind == .traffic { self.resetPendingTrafficSnapshotState() }
    }

    func webSocketTask(for kind: StreamKind) -> URLSessionWebSocketTask? {
        streamCoordinator.webSocketTask(for: kind.key)
    }

    func startTrafficStream() {
        self.startStream(
            kind: .traffic,
            makeWebSocket: { try $0.makeWebSocketTask(for: .traffic) },
            onPayload: { [weak self] payload in
                guard let self else { return }
                self.pendingTrafficPayload = payload
                self.flushPendingTrafficSnapshotIfNeeded()
            })
    }

    func flushPendingTrafficSnapshotIfNeeded(immediately: Bool = false) {
        guard self.pendingTrafficPayload != nil else { return }
        if immediately {
            self.publishPendingTrafficSnapshot()
            return
        }
        self.schedulePendingTrafficSnapshotPublishIfNeeded()
    }

    func startMemoryStream() {
        self.startDecodableStream(
            kind: .memory,
            makeWebSocket: { try $0.makeWebSocketTask(for: .memory) },
            onDecoded: { [weak self] (snapshot: MemorySnapshot) in
                guard let self else { return }
                memory = snapshot
            })
    }

    func startConnectionsStream(intervalMilliseconds: Int? = nil) {
        self.startDecodableStream(
            kind: .connections,
            makeWebSocket: {
                try $0.makeWebSocketTask(for: .connections(interval: intervalMilliseconds))
            },
            onDecoded: { [weak self] (snapshot: ConnectionsSnapshot) in
                guard let self else { return }
                self.applyConnectionsSnapshot(snapshot)
            })
        currentConnectionsStreamIntervalMilliseconds = intervalMilliseconds
    }

    func startLogsStream() {
        let level = self.logsStreamLevelFilter()
        self.startStream(
            kind: .logs,
            makeWebSocket: { try $0.makeWebSocketTask(for: .logs(level: level)) },
            onPayload: { [weak self] payload in
                guard let self else { return }
                if let line = decodeLogLinePayload(payload) {
                    appendMihomoLog(level: line.level, message: line.message)
                }
            })
        currentLogsStreamLevel = level
    }

    func logsStreamLevelFilter() -> String? {
        let runtimeLevel = self.logLevel.trimmed.lowercased()
        if ConfigLogLevel(rawValue: runtimeLevel) != nil {
            return runtimeLevel
        }

        let level = self.settingsLogLevel.trimmed.lowercased()
        guard ConfigLogLevel(rawValue: level) != nil else { return nil }
        return level
    }

    func refreshLogsStreamLevelIfNeeded() {
        guard self.webSocketTask(for: .logs) != nil else { return }
        guard currentLogsStreamLevel != self.logsStreamLevelFilter() else { return }
        self.startLogsStream()
    }

    private func schedulePendingTrafficSnapshotPublishIfNeeded() {
        guard self.trafficDecodeTask == nil else { return }

        let elapsed = Date().timeIntervalSince(self.lastTrafficDecodeAt)
        let publishInterval = Double(self.trafficPublishIntervalNanoseconds) / 1_000_000_000
        if elapsed >= publishInterval {
            self.publishPendingTrafficSnapshot()
            return
        }

        let remainingDelay = max(0.01, publishInterval - elapsed)
        let remainingNanoseconds = UInt64(remainingDelay * 1_000_000_000)
        self.trafficDecodeTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: remainingNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.publishPendingTrafficSnapshot()
        }
    }

    private func publishPendingTrafficSnapshot() {
        self.trafficDecodeTask?.cancel()
        self.trafficDecodeTask = nil

        guard let payload = self.pendingTrafficPayload else { return }
        self.pendingTrafficPayload = nil

        guard let snapshot = try? self.streamJSONDecoder.decode(TrafficSnapshot.self, from: payload)
        else {
            return
        }
        self.lastTrafficDecodeAt = Date()
        self.applyTrafficSnapshot(snapshot)

        if self.pendingTrafficPayload != nil {
            self.schedulePendingTrafficSnapshotPublishIfNeeded()
        }
    }

    private func applyTrafficSnapshot(_ snapshot: TrafficSnapshot) {
        self.traffic = snapshot
        guard self.isPanelPresented else {
            if !self.trafficHistoryUp.isEmpty
                || !self.trafficHistoryDown
                .isEmpty
                || self.displayUpTotal != 0 || self.displayDownTotal != 0
                || self.lastTrafficSampleAt != nil
            {
                self.clearTrafficPresentationHistory()
            }
            return
        }
        self.appendTrafficHistory(up: snapshot.up, down: snapshot.down)
        self.updateTrafficTotals(from: snapshot)
    }

    private func resetPendingTrafficSnapshotState() {
        self.trafficDecodeTask?.cancel()
        self.trafficDecodeTask = nil
        self.pendingTrafficPayload = nil
        self.lastTrafficDecodeAt = .distantPast
    }

    private func applyConnectionsSnapshot(_ snapshot: ConnectionsSnapshot) {
        let totalCount = snapshot.totalCount
        if connectionsStore.connectionsCount != totalCount {
            connectionsStore.connectionsCount = totalCount
        }

        if connectionsStore.connections != snapshot.connections {
            connectionsStore.connections = snapshot.connections
        }
    }

    func normalizedWebSocketPayload(from message: URLSessionWebSocketTask.Message) -> Data? {
        self.normalizeWebSocketPayloadUseCase.execute(message: message)
    }

    func startDecodableStream<Payload: Decodable>(
        kind: StreamKind,
        makeWebSocket: @escaping (MihomoAPIService) throws -> URLSessionWebSocketTask,
        onDecoded: @escaping (Payload) -> Void)
    {
        self.startStream(
            kind: kind,
            makeWebSocket: makeWebSocket,
            onPayload: { [weak self] payload in
                guard let self else { return }
                guard let decoded = try? self.streamJSONDecoder.decode(Payload.self, from: payload)
                else {
                    // Ignore malformed/empty payloads without reconnecting to avoid log storms.
                    return
                }
                onDecoded(decoded)
            })
    }

    func decodeLogLinePayload(_ payload: Data) -> (level: String, message: String)? {
        self.decodeStreamLogPayloadUseCase.execute(
            payload: payload, decoder: self.streamJSONDecoder)
    }
}
