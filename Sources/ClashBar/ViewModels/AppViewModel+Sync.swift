import Foundation

// MARK: - 同步状态

enum SyncStatus: Equatable {
    case idle
    case running
    case succeeded
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .idle:
            return "未同步"
        case .running:
            return "同步中…"
        case .succeeded:
            return "已同步"
        case let .failed(message):
            return "失败：\(message)"
        }
    }
}

// MARK: - 配置同步

@MainActor
extension AppViewModel {
    // MARK: 持久化

    func loadPersistedSyncSettings() {
        if let config = self.decodeFromDefaults(WebDAVConfig.self, key: webDAVConfigKey) {
            self.webDAVConfig = config
        } else {
            self.webDAVConfig = .empty
        }
        if let lastAt = self.defaults.object(forKey: syncLastAtKey) as? Date {
            self.lastSyncAt = lastAt
        }
        self.autoSyncEnabled = self.defaults.bool(forKey: syncAutoEnabledKey)
        self.syncOnLaunch = self.defaults.bool(forKey: syncOnLaunchKey)
    }

    func persistSyncSettings() {
        self.encodeToDefaults(self.webDAVConfig, key: webDAVConfigKey)
        if let lastSyncAt = self.lastSyncAt {
            self.defaults.set(lastSyncAt, forKey: syncLastAtKey)
        } else {
            self.defaults.removeObject(forKey: syncLastAtKey)
        }
        self.defaults.set(self.autoSyncEnabled, forKey: syncAutoEnabledKey)
        self.defaults.set(self.syncOnLaunch, forKey: syncOnLaunchKey)
    }

    // MARK: 快照收集

    /// 汇总当前配置与设置，生成待同步快照。
    ///
    /// 只收集"非订阅派生"的配置：订阅内容由各平台自行按 URL 拉取，纳入同步只会让
    /// 设备之间用过期的节点列表互相覆盖。判定依据就是 `remoteConfigSubscriptions` 的 key。
    func makeSyncSnapshot(at date: Date = Date()) throws -> LocalSyncSnapshot {
        let directory = self.workingDirectoryManager.configDirectoryURL
        let subscriptionNames = Set(self.remoteConfigSubscriptions.keys)

        let configs = try ConfigDirectoryManager
            .scanConfigFiles(in: directory)
            .filter { !subscriptionNames.contains($0.lastPathComponent) }
            .map { url -> LocalConfigFile in
                let name = try SyncService.normalizeConfigFileName(url.lastPathComponent)
                guard let data = try? Data(contentsOf: url) else {
                    throw SyncError.configFileMissing(name)
                }
                return LocalConfigFile(name: name, data: data)
            }

        let payload = SyncPayload(
            updatedAt: date,
            updatedBy: SyncService.defaultDeviceName,
            selectedConfig: self.resolvedSyncConfigFileName(),
            core: Self.coreSection(from: self.currentEditableSettingsSnapshot()),
            subscriptions: self.syncSubscriptionSections(),
            systemProxy: SystemProxySection(
                enabledOnQuit: self.defaults.bool(forKey: self.systemProxyEnabledOnQuitKey),
                exceptions: self.systemProxyExceptions.map(\.value)),
            ui: UISection(
                language: self.uiLanguage.rawValue,
                appearance: self.appearanceMode.rawValue),
            ssidRules: self.ssidStrategyRules.map {
                SSIDSection(ssid: $0.ssid, configFileName: $0.configFileName)
            })

        return LocalSyncSnapshot(configs: configs, payload: payload)
    }

    private func resolvedSyncConfigFileName() -> String {
        let name = self.selectedConfigName.trimmed
        if !name.isEmpty, name != "-", name.hasSuffix(".yaml") || name.hasSuffix(".yml") {
            return name
        }
        return SyncService.defaultConfigFileName
    }

    private func syncSubscriptionSections() -> [SubscriptionSection] {
        self.remoteConfigSubscriptions
            .sorted { $0.key < $1.key }
            .map { fileName, subscription in
                SubscriptionSection(
                    name: fileName,
                    url: subscription.urlString,
                    autoUpdate: subscription.autoUpdateEnabled,
                    intervalHours: subscription.autoUpdateIntervalHours,
                    lastUpdateAt: subscription.lastUpdateCheckAt)
            }
    }

    private static func coreSection(from snapshot: EditableSettingsSnapshot) -> CoreSection {
        CoreSection(
            mode: snapshot.mode.rawValue,
            allowLan: snapshot.allowLan,
            ipv6: snapshot.ipv6,
            tcpConcurrent: snapshot.tcpConcurrent,
            tunEnabled: snapshot.tunEnabled,
            logLevel: snapshot.logLevel,
            ports: PortsSection(
                http: Int(snapshot.port.trimmed) ?? 0,
                socks: Int(snapshot.socksPort.trimmed) ?? 0,
                mixed: Int(snapshot.mixedPort.trimmed) ?? 7890,
                redir: Int(snapshot.redirPort.trimmed) ?? 0,
                tproxy: Int(snapshot.tproxyPort.trimmed) ?? 0))
    }

    // MARK: 应用远端

    /// 应用远端设置到本地。配置文件本身由 `SyncService.pull` 写入。
    func applySyncPayload(_ payload: SyncPayload) async {
        // UI 偏好
        if let language = AppLanguage(rawValue: payload.ui.language) {
            self.setUILanguage(language)
        }
        if let mode = AppAppearanceMode(rawValue: payload.ui.appearance) {
            self.setAppearanceMode(mode)
        }

        // 订阅
        var subscriptions: [String: RemoteConfigSubscription] = [:]
        for item in payload.subscriptions {
            let name = item.name.trimmed
            guard !name.isEmpty, !item.url.trimmed.isEmpty else { continue }
            subscriptions[name] = RemoteConfigSubscription(
                urlString: item.url,
                autoUpdateEnabled: item.autoUpdate,
                autoUpdateIntervalHours: item.intervalHours,
                lastUpdateCheckAt: item.lastUpdateAt)
        }
        self.remoteConfigSubscriptions = subscriptions
        self.persistRemoteConfigSubscriptions()

        // 系统代理绕过
        if !payload.systemProxy.exceptions.isEmpty {
            self.systemProxyExceptions = payload.systemProxy.exceptions
                .map { EditableSystemProxyException(value: $0) }
            self.persistSystemProxyExceptions()
        }
        self.defaults.set(
            payload.systemProxy.enabledOnQuit,
            forKey: self.systemProxyEnabledOnQuitKey)

        // SSID 规则
        if !payload.ssidRules.isEmpty {
            self.ssidStrategyRules = SSIDStrategyRule.normalized(
                payload.ssidRules.map {
                    SSIDStrategyRule(ssid: $0.ssid, configFileName: $0.configFileName)
                })
            self.persistSSIDStrategyRules(self.ssidStrategyRules)
        }

        // 配置文件已由 SyncService 写入磁盘，刷新文件列表并重载核心
        self.reloadConfigFileList()

        // 只有目标文件确实存在时才切换选中项：`selectedConfig` 可能是一个尚未在本机
        // 下载的订阅配置（订阅只同步 URL），直接写 defaults 会让 UI 指向不存在的文件。
        let target = payload.selectedConfig.trimmed
        guard !target.isEmpty,
              let matched = self.configService.availableConfigs.first(where: {
                  $0.lastPathComponent == target
              })
        else {
            return
        }
        self.configService.selectConfig(matched)
        _ = self.syncSelectedConfigSelection(matched)
        self.syncConfigDisplayState()
    }

    // MARK: 操作

    func pushSync() async {
        guard let service = self.makeSyncService() else { return }
        guard self.beginSync() else { return }

        do {
            let snapshot = try self.makeSyncSnapshot()
            let outcome = try await service.push(snapshot)
            self.completeSync(
                outcome: outcome,
                message: self.tr("app.sync.pushed")
                    .isEmpty ? "已上传到云端" : self.tr("app.sync.pushed"))
        } catch {
            self.failSync(error)
        }
    }

    func pullSync() async {
        guard let service = self.makeSyncService() else { return }
        guard self.beginSync() else { return }

        do {
            let result = try await service.pull()
            await self.applySyncPayload(result.payload)
            let outcome = SyncOutcome(
                action: .pulled,
                remoteDeviceName: result.metadata.deviceName,
                remoteUpdatedAt: result.metadata.updatedAt,
                bytesTransferred: 0)
            self.completeSync(
                outcome: outcome,
                message: self.tr("app.sync.pulled").isEmpty ? "已从云端下载" : self.tr("app.sync.pulled"))
            await self.reloadConfig()
        } catch {
            self.failSync(error)
        }
    }

    func runSync() async {
        guard let service = self.makeSyncService() else { return }
        guard self.beginSync() else { return }

        do {
            let snapshot = try self.makeSyncSnapshot()
            let result = try await service.sync(snapshot)
            // 拉取分支已带回 payload，无需再请求一次远端
            if let payload = result.pulledPayload {
                await self.applySyncPayload(payload)
                await self.reloadConfig()
            }
            self.completeSync(
                outcome: result.outcome,
                message: Self.describe(outcome: result.outcome))
        } catch {
            self.failSync(error)
        }
    }

    // MARK: 内部

    private func makeSyncService() -> SyncService? {
        guard self.webDAVConfig.isConfigured else {
            self.syncStatus = .failed(self.tr("app.sync.error.not_configured").isEmpty
                ? "请先填写 WebDAV 配置"
                : self.tr("app.sync.error.not_configured"))
            return nil
        }
        do {
            return try SyncService(
                config: self.webDAVConfig,
                directories: self.workingDirectoryManager)
        } catch {
            self.syncStatus = .failed(error.localizedDescription)
            return nil
        }
    }

    /// 返回 false 表示已有同步在进行或未配置。
    private func beginSync() -> Bool {
        guard !self.syncStatus.isRunning else { return false }
        self.syncStatus = .running
        self.lastSyncMessage = nil
        return true
    }

    private func completeSync(outcome: SyncOutcome, message: String) {
        self.syncStatus = .succeeded
        self.lastSyncAt = Date()
        self.lastSyncMessage = message
        self.lastSyncDeviceName = outcome.remoteDeviceName
        self.persistSyncSettings()
        self.appendLog(level: "info", message: "[Sync] \(message)")
    }

    private func failSync(_ error: Error) {
        let message = error.localizedDescription
        self.syncStatus = .failed(message)
        self.lastSyncMessage = message
        self.appendLog(level: "error", message: "[Sync] 失败：\(message)")
    }

    private static func describe(outcome: SyncOutcome) -> String {
        switch outcome.action {
        case .pushed:
            return "已上传到云端"
        case .pulled:
            return "已从云端下载"
        case .upToDate:
            return "已是最新"
        }
    }
}
