import Foundation

@MainActor
extension AppViewModel {
    var ssidStrategyEnabled: Bool {
        get { self.ssidStrategyEnabledStorage }
        set {
            guard self.ssidStrategyEnabledStorage != newValue else { return }
            self.ssidStrategyEnabledStorage = newValue
            self.handleSSIDStrategyEnabledStateChanged()
        }
    }

    var isSSIDStrategyAuthorized: Bool {
        self.ssidStrategyAuthorizationStatus == .authorized
    }

    @discardableResult
    func startSSIDStrategyMonitoringIfNeeded() -> Bool {
        guard !self.isSSIDStrategyMonitoring else { return false }
        self.isSSIDStrategyMonitoring = true

        self.ssidMonitorService.start { [weak self] snapshot in
            Task { @MainActor in
                self?.handleSSIDMonitorSnapshot(snapshot)
            }
        } errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.appendLog(
                    level: "error",
                    message: self?.tr("log.ssid_strategy.monitor_failed", error.localizedDescription) ?? "")
            }
        }

        return true
    }

    func refreshSSIDStrategyState(requestAuthorizationIfNeeded: Bool = false) {
        // The first enable of SSID auto-switch must still reach
        // `requestAuthorizationIfNeeded()` even when monitoring is booted up
        // in this same call — otherwise the system permission sheet never
        // appears and the feature looks broken on first use.
        let justStartedMonitoring = self.startSSIDStrategyMonitoringIfNeeded()
        if requestAuthorizationIfNeeded {
            self.ssidMonitorService.requestAuthorizationIfNeeded()
        } else if !justStartedMonitoring {
            self.ssidMonitorService.refresh()
        }
    }

    func handleSSIDStrategyAppDidBecomeActive() {
        self.refreshSSIDStrategyState(requestAuthorizationIfNeeded: self.ssidStrategyEnabled)
    }

    func toggleCurrentSSIDBinding(for configFileName: String) {
        guard !self.isRemoteTarget else { return }
        let normalizedConfigFileName = configFileName.trimmed
        guard !normalizedConfigFileName.isEmpty else { return }

        guard self.ssidStrategyEnabled else {
            self.pendingSSIDBindingConfigFileName = nil
            self.logSSIDStrategyEnableFirstIfNeeded()
            return
        }

        self.refreshSSIDStrategyState()

        if !self.isSSIDStrategyAuthorized {
            self.pendingSSIDBindingConfigFileName = normalizedConfigFileName
            self.refreshSSIDStrategyState(requestAuthorizationIfNeeded: true)
        }

        guard self.isSSIDStrategyAuthorized else {
            self.logSSIDStrategyAuthorizationRequirementIfNeeded()
            return
        }
        self.pendingSSIDBindingConfigFileName = nil

        guard let currentSSID = self.ssidStrategyCurrentSSID?.trimmedNonEmpty else {
            self.appendLog(level: "warning", message: self.tr("log.ssid_strategy.current_wifi_unavailable"))
            return
        }

        if self.ssidStrategyRules.contains(where: {
            $0.ssid == currentSSID && $0.configFileName == normalizedConfigFileName
        }) {
            self.removeSSIDStrategyBinding(ssid: currentSSID)
            return
        }

        self.bindSSID(currentSSID, to: normalizedConfigFileName)
    }

    func removeSSIDStrategyBinding(ssid: String) {
        let normalizedSSID = ssid.trimmed
        guard !normalizedSSID.isEmpty else { return }

        guard self.setSSIDStrategyRules(
            SSIDStrategyRule.removing(ssid: normalizedSSID, from: self.ssidStrategyRules))
        else {
            return
        }
        self.appendLog(level: "info", message: self.tr("log.ssid_strategy.unbound", normalizedSSID))
    }

    func applySSIDStrategyForCurrentSSIDIfNeeded() async {
        guard self.ssidStrategyEnabled else { return }
        guard !self.isRemoteTarget else { return }

        guard self.isSSIDStrategyAuthorized else {
            self.logSSIDStrategyAuthorizationRequirementIfNeeded()
            return
        }

        let resolution = ResolveSSIDStrategyConfigUseCase().execute(
            currentSSID: self.ssidStrategyCurrentSSID,
            currentConfigName: self.selectedConfigName,
            rules: self.ssidStrategyRules,
            availableConfigNames: self.availableConfigFileNames)

        switch resolution {
        case .noAction:
            self.ssidStrategyLastLogFingerprint = nil
        case let .missingConfig(configName):
            self.logSSIDStrategyOnce(
                level: "warning",
                fingerprint: "missing-config:\(configName)",
                message: self.tr("log.ssid_strategy.config_missing", configName))
        case let .switchToConfig(configName):
            self.ssidStrategyLastLogFingerprint = nil
            let currentSSID = self.ssidStrategyCurrentSSID ?? self.tr("ui.common.unknown")
            self.appendLog(
                level: "info",
                message: self.tr(
                    "log.ssid_strategy.switching",
                    currentSSID,
                    configName))
            await self.selectConfigFile(named: configName)
            if self.selectedConfigName.trimmed == configName.trimmed {
                self.statusItemBanner = StatusItemBanner(
                    symbolName: "wifi.circle.fill",
                    title: self.tr("ui.banner.ssid_strategy.title"),
                    primaryDetail: configName.trimmed,
                    secondaryDetail: currentSSID.trimmedNonEmpty)
            }
        }
    }

    func ssidStrategyAuthorizationStatusText() -> String {
        switch self.ssidStrategyAuthorizationStatus {
        case .authorized:
            self.tr("ui.settings.ssid_strategy.status.authorized")
        case .notDetermined:
            self.tr("ui.settings.ssid_strategy.status.not_determined")
        case .denied:
            self.tr("ui.settings.ssid_strategy.status.denied")
        case .restricted:
            self.tr("ui.settings.ssid_strategy.status.restricted")
        case .servicesDisabled:
            self.tr("ui.settings.ssid_strategy.status.services_disabled")
        }
    }

    func ssidStrategyCurrentSSIDText() -> String {
        self.ssidStrategyCurrentSSID?.trimmedNonEmpty ?? self.tr("ui.settings.ssid_strategy.current_ssid.none")
    }

    private func handleSSIDStrategyEnabledStateChanged() {
        if self.ssidStrategyEnabled {
            self.refreshSSIDStrategyState(requestAuthorizationIfNeeded: true)
            self.scheduleSSIDStrategyApplication()
        } else {
            self.pendingSSIDBindingConfigFileName = nil
            self.ssidStrategyLastLogFingerprint = nil
            self.ssidStrategyApplyTask?.cancel()
            self.ssidStrategyApplyTask = nil
            if self.isSSIDStrategyMonitoring {
                self.ssidMonitorService.stop()
                self.isSSIDStrategyMonitoring = false
            }
        }
    }

    private func bindSSID(_ ssid: String, to configFileName: String, applyStrategy: Bool = true) {
        let normalizedSSID = ssid.trimmed
        let normalizedConfigFileName = configFileName.trimmed
        guard !normalizedSSID.isEmpty, !normalizedConfigFileName.isEmpty else { return }
        guard self.setSSIDStrategyRules(
            SSIDStrategyRule.upserting(
                ssid: normalizedSSID,
                configFileName: normalizedConfigFileName,
                into: self.ssidStrategyRules),
            applyStrategy: applyStrategy)
        else {
            return
        }

        self.appendLog(
            level: "info",
            message: self.tr("log.ssid_strategy.bound", normalizedSSID, normalizedConfigFileName))
    }

    @discardableResult
    private func setSSIDStrategyRules(_ rules: [SSIDStrategyRule], applyStrategy: Bool = true) -> Bool {
        let normalizedRules = SSIDStrategyRule.normalized(rules)
        guard normalizedRules != self.ssidStrategyRules else {
            if applyStrategy, self.ssidStrategyEnabled {
                self.scheduleSSIDStrategyApplication()
            }
            return false
        }

        self.ssidStrategyRules = normalizedRules
        self.persistSSIDStrategyRules(normalizedRules)

        if applyStrategy, self.ssidStrategyEnabled {
            self.scheduleSSIDStrategyApplication()
        }

        return true
    }

    private func scheduleSSIDStrategyApplication() {
        self.ssidStrategyApplyTask?.cancel()
        // Task inherits MainActor isolation from this enclosing @MainActor
        // extension, so an explicit `@MainActor` annotation is redundant.
        self.ssidStrategyApplyTask = Task { [weak self] in
            await self?.applySSIDStrategyForCurrentSSIDIfNeeded()
            self?.ssidStrategyApplyTask = nil
        }
    }

    private func handleSSIDMonitorSnapshot(_ snapshot: SSIDMonitorSnapshot) {
        let previousSSID = self.ssidStrategyCurrentSSID
        let previousAuthorizationStatus = self.ssidStrategyAuthorizationStatus
        let previousRules = self.ssidStrategyRules

        self.ssidStrategyCurrentSSID = snapshot.currentSSID
        self.ssidStrategyAuthorizationStatus = snapshot.authorizationStatus

        self.resolvePendingSSIDBindingIfNeeded(for: snapshot)

        guard self.ssidStrategyEnabled else { return }
        guard previousSSID != self.ssidStrategyCurrentSSID
            || previousAuthorizationStatus != self.ssidStrategyAuthorizationStatus
            || previousRules != self.ssidStrategyRules
        else {
            return
        }

        self.scheduleSSIDStrategyApplication()
    }

    private func resolvePendingSSIDBindingIfNeeded(for snapshot: SSIDMonitorSnapshot) {
        guard let pendingConfigFileName = self.pendingSSIDBindingConfigFileName?.trimmedNonEmpty else { return }

        switch snapshot.authorizationStatus {
        case .authorized:
            guard let currentSSID = snapshot.currentSSID?.trimmedNonEmpty else { return }
            self.pendingSSIDBindingConfigFileName = nil
            if !self.ssidStrategyRules.contains(where: {
                $0.ssid == currentSSID && $0.configFileName == pendingConfigFileName
            }) {
                self.bindSSID(currentSSID, to: pendingConfigFileName, applyStrategy: false)
            }
        case .notDetermined:
            break
        case .denied, .restricted, .servicesDisabled:
            self.pendingSSIDBindingConfigFileName = nil
        }
    }

    private func logSSIDStrategyAuthorizationRequirementIfNeeded() {
        self.logSSIDStrategyOnce(
            level: "warning",
            fingerprint: "authorization:\(self.ssidStrategyAuthorizationStatus)",
            message: self.tr("log.ssid_strategy.authorization_required"))
    }

    private func logSSIDStrategyEnableFirstIfNeeded() {
        self.logSSIDStrategyOnce(
            level: "info",
            fingerprint: "enable-first",
            message: self.tr("log.ssid_strategy.enable_auto_switch_first"))
    }

    private func logSSIDStrategyOnce(level: String, fingerprint: String, message: String) {
        guard self.ssidStrategyLastLogFingerprint != fingerprint else { return }
        self.ssidStrategyLastLogFingerprint = fingerprint
        self.appendLog(level: level, message: message)
    }
}
