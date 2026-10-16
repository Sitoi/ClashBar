import Foundation

@MainActor
extension AppViewModel {
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
            if self.networkReachabilityStatus == .offline {
                return false
            }
            return self.isRemoteTarget || self.processManager.isRunning
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
        onPayload: @escaping (Data) async -> Void)
    {
        if kind == .connections {
            currentConnectionsStreamIntervalMilliseconds = nil
        }
        if kind == .logs {
            currentLogsStreamLevel = nil
        }
        if kind == .traffic {
            self.resetPendingTrafficSnapshotState()
        }

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
                StreamCoordinator.normalizeWebSocketPayload(message)
            })
    }

    func cancelStream(_ kind: StreamKind, resetReconnectState: Bool = true) {
        streamCoordinator.cancel(key: kind.key, resetReconnectState: resetReconnectState)
        if kind == .connections {
            currentConnectionsStreamIntervalMilliseconds = nil
        }
        if kind == .logs {
            currentLogsStreamLevel = nil
        }
        if kind == .traffic {
            self.resetPendingTrafficSnapshotState()
        }
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

    func enableTrafficStatisticsProcessMatching() async {
        guard !self.isRemoteTarget else { return }
        do {
            try await self.clientOrThrow().requestNoResponse(
                .patchConfigs(body: ["find-process-mode": .string("always")]))
        } catch {
            self.appendLog(
                level: "warning",
                message: self.tr("log.statistics.process_matching_failed", error.localizedDescription))
        }
    }

    func startConnectionsStream(intervalMilliseconds: Int? = nil) {
        let service = self.connectionStatisticsService
        var needsProcessMatching = true
        self.startStream(
            kind: .connections,
            makeWebSocket: {
                try $0.makeWebSocketTask(for: .connections(interval: intervalMilliseconds))
            },
            onPayload: { [weak self] payload in
                guard !Task.isCancelled, let self else { return }
                if needsProcessMatching {
                    needsProcessMatching = false
                    // The first frame confirms the controller is ready to accept the config patch.
                    await self.enableTrafficStatisticsProcessMatching()
                }
                let connectionsVisible = self.isPanelPresented && self.activeMenuTab == .connections
                let dimension = connectionsVisible && self.connectionsStore.showsStatistics
                    ? self.connectionsStore.statisticsDimension : nil
                guard let update = try? await service.process(
                    payload,
                    includeConnections: connectionsVisible && !self.connectionsStore.showsStatistics,
                    statisticsDimension: dimension),
                    !Task.isCancelled,
                    service === self.connectionStatisticsService
                else { return }
                self.applyConnectionsUpdate(update)
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
        self.appendTrafficHistory(up: snapshot.up, down: snapshot.down)
        guard self.isPanelPresented else { return }
        self.updateTrafficTotals(from: snapshot)
    }

    private func resetPendingTrafficSnapshotState() {
        self.trafficDecodeTask?.cancel()
        self.trafficDecodeTask = nil
        self.pendingTrafficPayload = nil
        self.lastTrafficDecodeAt = .distantPast
    }

    private func applyConnectionsUpdate(_ update: ConnectionStatisticsUpdate) {
        guard self.isPanelPresented else { return }

        if self.activeMenuTab == .proxy || self.activeMenuTab == .connections,
           self.connectionsStore.connectionsCount != update.totalCount
        {
            self.connectionsStore.connectionsCount = update.totalCount
        }

        guard self.activeMenuTab == .connections else { return }
        if !self.connectionsStore.showsStatistics,
           let connections = update.connections,
           self.connectionsStore.connections != connections
        {
            self.connectionsStore.connections = connections
        }
        if self.connectionsStore.showsStatistics,
           let statistics = update.statistics,
           statistics.dimension == self.connectionsStore.statisticsDimension,
           self.connectionsStore.statistics != statistics
        {
            self.connectionsStore.statistics = statistics
        }
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
                    return
                }
                onDecoded(decoded)
            })
    }

    func decodeLogLinePayload(_ payload: Data) -> (level: String, message: String)? {
        if let log = try? self.streamJSONDecoder.decode(LogLine.self, from: payload) {
            let level = (log.type?.isEmpty == false) ? (log.type ?? "info") : "info"
            let message = log.payload?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !message.isEmpty {
                return (level: level, message: message)
            }
        }

        if let response = try? self.streamJSONDecoder.decode(LogsResponse.self, from: payload),
           let first = response.logs?.first
        {
            let level = (first.type?.isEmpty == false) ? (first.type ?? "info") : "info"
            let message = first.payload?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !message.isEmpty {
                return (level: level, message: message)
            }
        }

        if let text = String(data: payload, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        {
            return (level: "info", message: text)
        }

        return nil
    }
}
