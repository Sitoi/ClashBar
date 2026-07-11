import AppKit

@MainActor
extension AppViewModel {
    func switchMode(to target: CoreMode) async {
        if !isModeSwitchEnabled || modeSwitchInFlight || target == currentMode { return }
        modeSwitchInFlight = true
        defer { modeSwitchInFlight = false }

        let previous = currentMode
        currentMode = target
        persistEditableSettingsSnapshot()

        do {
            try await self.clientOrThrow()
                .requestNoResponse(.patchConfigs(body: ["mode": .string(target.rawValue)]))
        } catch {
            currentMode = previous
            persistEditableSettingsSnapshot()
            appendLog(
                level: "error",
                message: tr(
                    "log.action.failed",
                    tr("log.action_name.switch_mode", target.rawValue),
                    error.localizedDescription))
        }
    }

    func toggleSystemProxy(_ enabled: Bool) async {
        isProxySyncing = true
        self.systemProxyEnableIntentInFlight = enabled
        self.clearSystemProxyOpenFailureHint()
        defer { isProxySyncing = false }
        defer { self.systemProxyEnableIntentInFlight = false }

        do {
            if enabled {
                let target = try await resolveSystemProxyTargetFromRuntimeConfig()
                try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                try await self.applyCurrentSystemProxyExceptionsIfNeeded()
                systemProxyActiveDisplay = self.buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            } else {
                try await applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
                systemProxyActiveDisplay = nil
            }

            try await self.clientOrThrow()
                .requestNoResponse(.patchConfigs(body: ["mode": .string(currentMode.rawValue)]))

            isSystemProxyEnabled = enabled
            self.clearSystemProxyOpenFailureHint()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
            if enabled {
                await self.refreshSystemProxyHelperRuntimeSnapshot()
            } else {
                self.resetSystemProxyObservedState()
            }
            let state = enabled ? tr("log.system_proxy.enabled") : tr("log.system_proxy.disabled")
            appendLog(level: "info", message: tr("log.system_proxy.toggled", state))
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.toggle_failed", systemProxyErrorMessage(error)))
            if enabled {
                self.updateSystemProxyOpenFailureHint(for: error)
            }
            await self.refreshSystemProxyHelperStatus()
            if enabled || self.isSystemProxyEnabled {
                await refreshSystemProxyStatus()
            } else {
                self.resetSystemProxyObservedState()
            }
        }
    }

    func copyProxyCommand() {
        self.copyLocalProxyCommand()
    }

    func copyLocalProxyCommand() {
        self.copyProxyCommand(host: "127.0.0.1")
    }

    func copyManagedEndpointProxyCommand() {
        self.copyProxyCommand(host: self.managedEndpointProxyCommandHost())
    }

    func localProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        return self.buildSystemProxyDisplayString(host: "127.0.0.1", ports: ports) ?? "127.0.0.1"
    }

    func localProxyCommandHostDisplay() -> String {
        "127.0.0.1"
    }

    func managedEndpointProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        let host = self.managedEndpointProxyCommandHost()
        return self.buildSystemProxyDisplayString(host: host, ports: ports) ?? host
    }

    func managedEndpointProxyCommandHostDisplay() -> String {
        self.managedEndpointProxyCommandHost()
    }

    private func copyProxyCommand(host: String) {
        let ports = currentSystemProxyPortsFromState()
        let httpPort = ports.httpPort ?? ports.socksPort ?? effectiveMixedPort()
        let socksPort = ports.socksPort ?? ports.httpPort ?? httpPort
        let script = BuildTerminalProxyCommandUseCase().execute(host: host, httpPort: httpPort, socksPort: socksPort)
        copyTextToPasteboard(script)
        appendLog(level: "info", message: tr("log.proxy_export.copied"))
    }

    func switchProxy(group: String, target: String) async {
        await runNoResponseAction(tr("log.action_name.switch_proxy", group, target)) {
            try await self.clientOrThrow().requestNoResponse(.switchProxy(name: group, target: target))
            await self.refreshProxyGroups()
        }
    }

    func refreshGroupLatency(_ group: ProxyGroup) async {
        groupLatencyLoading.insert(group.name)
        defer { groupLatencyLoading.remove(group.name) }

        let testURL = group.testUrl?.trimmedNonEmpty ?? defaultHealthcheckURL
        let timeout = group.timeout.flatMap { $0 > 0 ? $0 : nil } ?? defaultHealthcheckTimeoutMilliseconds
        await runRefresh {
            let response: GroupDelayMeasurement = try await self.clientOrThrow().request(
                .groupDelay(name: group.name, url: testURL, timeout: timeout))
            let delays = response.values.filter { $0.value > 0 }

            self.groupLatencies[group.name] = delays
        }
    }

    func refreshAllGroupLatencies(includeHiddenGroups: Bool = false) async {
        let modeScopedGroups = self.currentMode == .global
            ? self.proxyGroups
            : self.proxyGroups.filter { $0.name.caseInsensitiveCompare("GLOBAL") != .orderedSame }
        let groups = includeHiddenGroups
            ? modeScopedGroups
            : modeScopedGroups.filter { $0.hidden != true }
        await withTaskGroup(of: Void.self) { taskGroup in
            for group in groups {
                taskGroup.addTask { [weak self] in
                    await self?.refreshGroupLatency(group)
                }
            }
        }
    }

    func isProxyLatencyTesting(group: String, node: String) -> Bool {
        self.proxyLatencyTesting.contains(ProxyLatencyTestKey(group: group, node: node))
    }

    func refreshProxyLatency(group: String, node: String) async {
        let key = ProxyLatencyTestKey(group: group, node: node)
        guard !self.proxyLatencyTesting.contains(key) else { return }

        self.proxyLatencyTesting.insert(key)
        defer { self.proxyLatencyTesting.remove(key) }

        let proxyGroup = self.proxyGroups.first { $0.name == group }
        let testURL = proxyGroup?.testUrl?.trimmedNonEmpty ?? defaultHealthcheckURL
        let timeout = proxyGroup?.timeout.flatMap { $0 > 0 ? $0 : nil } ?? defaultHealthcheckTimeoutMilliseconds

        await runRefresh {
            let response: DelayMeasurement = try await self.clientOrThrow().request(
                .proxyDelay(name: node, url: testURL, timeout: timeout))
            guard let value = response.value else { return }

            var groupDelays = self.groupLatencies[group] ?? [:]
            groupDelays[node] = value
            self.groupLatencies[group] = groupDelays
        }
    }

    func delayText(group: String, node: String, fallbackToGroupHistory: Bool = false) -> String {
        guard let value = delayValue(
            group: group,
            node: node,
            fallbackToGroupHistory: fallbackToGroupHistory)
        else { return tr("ui.common.unknown") }
        if value == 0 { return tr("ui.common.timeout") }
        return tr("ui.common.latency_ms", value)
    }

    func delayValue(group: String, node: String, fallbackToGroupHistory: Bool = false) -> Int? {
        if let liveValue = groupLatencies[group]?[node] {
            return liveValue
        }
        if let historyValue = proxyHistoryLatestDelay[node] {
            return historyValue
        }
        if fallbackToGroupHistory {
            return proxyHistoryLatestDelay[group]
        }
        return nil
    }

    func controllerHost() -> String {
        guard let host = controllerHost(from: controller), !host.isEmpty else {
            return "127.0.0.1"
        }
        return host
    }

    private func managedEndpointProxyCommandHost() -> String {
        guard !self.isRemoteTarget else {
            return self.controllerHost()
        }

        let configuredHost = self.controllerHost(from: self.localExternalControllerDisplay) ?? self.controllerHost()
        guard self.settingsAllowLan else {
            return configuredHost
        }
        guard self.shouldUseCurrentDeviceIPv4ForProxyCommand(host: configuredHost) else {
            return configuredHost
        }

        return DeviceIPv4AddressResolver.currentAddress() ?? self.controllerHost()
    }

    private func shouldUseCurrentDeviceIPv4ForProxyCommand(host: String) -> Bool {
        switch host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "localhost", "127.0.0.1", "::1", "0.0.0.0", "::", "0:0:0:0:0:0:0:0":
            true
        default:
            false
        }
    }

    func buildSystemProxyDisplayString(host: String, ports: SystemProxyPorts) -> String? {
        guard let port = ports.primaryPort, port > 0 else { return nil }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]:\(port)"
        }
        return "\(trimmedHost):\(port)"
    }

    func makeControllerUIURL(
        _ controller: String,
        secret: String? = nil,
        hasConfiguredExternalUI: Bool? = nil,
        externalUIName: String? = nil) -> String
    {
        let resolvedSecret = secret ?? self.controllerSecret
        let resolvedHasConfiguredExternalUI = hasConfiguredExternalUI ?? self.hasConfiguredExternalUI
        let resolvedExternalUIName = externalUIName ?? self.configuredExternalUIName

        if resolvedHasConfiguredExternalUI {
            return self.configuredControllerUIURL(controller, externalUIName: resolvedExternalUIName)
        }
        return self.metaCubeXDSetupURL(controller, secret: resolvedSecret)
    }

    func openControllerWebUI() {
        guard let url = URL(string: self.controllerUIURL) else { return }
        _ = NSWorkspace.shared.open(url)
    }

    private func configuredControllerUIURL(_ controller: String, externalUIName: String?) -> String {
        guard var components = URLComponents(string: self.normalizedControllerAddress(controller)) else {
            return "\(self.normalizedControllerAddress(controller))/ui"
        }

        var path = "/ui"
        if let externalUIName = externalUIName?.trimmedNonEmpty {
            path += "/\(self.encodedURLPathComponent(externalUIName))"
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.string ?? "\(self.normalizedControllerAddress(controller))\(path)"
    }

    private func metaCubeXDSetupURL(_ controller: String, secret: String?) -> String {
        let controllerComponents = URLComponents(string: self.normalizedControllerAddress(controller))
        let usesHTTPS = controllerComponents?.scheme?.lowercased() == "https"
        let host = controllerComponents?.host?.trimmedNonEmpty ?? "127.0.0.1"
        let port = controllerComponents?.port ?? (usesHTTPS ? 443 : 80)

        var fragmentComponents = URLComponents()
        fragmentComponents.path = "/setup"
        fragmentComponents.queryItems = [
            URLQueryItem(name: "http", value: usesHTTPS ? "false" : "true"),
            URLQueryItem(name: "hostname", value: host),
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "secret", value: secret?.trimmed ?? ""),
        ]

        var components = URLComponents(string: "https://metacubex.github.io/metacubexd/")!
        components.fragment = fragmentComponents.string
        return components.string ?? "https://metacubex.github.io/metacubexd/#/setup"
    }

    private func encodedURLPathComponent(_ value: String) -> String {
        let allowedCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }
}

extension AppViewModel {
    func resolvedConnectionHost(for connection: ConnectionSummary) -> String? {
        let host = connection.metadata?.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !host.isEmpty {
            return host
        }

        let destinationIP = connection.metadata?.destinationIP?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !destinationIP.isEmpty {
            return destinationIP
        }
        return nil
    }

    func copyConnectionHost(_ host: String) {
        self.copyAndLog(host, message: tr("log.connection.copy_host", host))
    }

    func copyConnectionID(_ id: String) {
        self.copyAndLog(id, message: tr("log.connection.copy_id", id))
    }

    func copyLogMessage(_ log: AppErrorLogEntry) {
        self.copyAndLog(log.message, message: tr("log.logs.copied_message"))
    }

    func copyLogEntry(_ log: AppErrorLogEntry) {
        self.copyAndLog(self.formattedLogEntry(log), message: tr("log.logs.copied_entry"))
    }

    func copyTextToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func formattedLogEntry(_ log: AppErrorLogEntry) -> String {
        let source = log.source.rawValue.uppercased()
        return "[\(ValueFormatter.dateTime(log.timestamp))] [\(source)] [\(log.level.uppercased())] \(log.message)"
    }

    private func copyAndLog(_ text: String, message: String) {
        self.copyTextToPasteboard(text)
        appendLog(level: "info", message: message)
    }
}

extension AppViewModel {
    func closeAllConnections() async {
        await self.runConnectionMutation(
            actionName: tr("log.action_name.close_all_connections"),
            operation: {
                try await self.clientOrThrow().requestNoResponse(.closeAllConnections)
            })
    }

    func closeConnection(id: String) async {
        await self.runConnectionMutation(
            actionName: tr("log.action_name.close_connection", id),
            operation: {
                try await self.clientOrThrow().requestNoResponse(.closeConnection(id: id))
            })
    }

    func copyAllLogs() {
        self.flushPendingMihomoLogsIfNeeded()
        let content = errorLogs
            .map(self.formattedLogEntry)
            .joined(separator: "\n")

        self.copyTextToPasteboard(content)
        appendLog(level: "info", message: tr("log.logs.copied_all", errorLogs.count))
    }

    private func runConnectionMutation(actionName: String, operation: @escaping () async throws -> Void) async {
        await runNoResponseAction(actionName) {
            try await operation()
            await self.refreshConnections()
        }
    }
}
