import AppKit

// MARK: - Modal Window Helpers

@MainActor
extension AppViewModel {
    func prepareModalWindowPresentation() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func configureModalWindow(_ window: NSWindow) {
        window.level = .statusBar
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    @discardableResult
    func runModalAlert(
        style: NSAlert.Style,
        message: String,
        informative: String,
        buttons: [String],
        configure: ((NSAlert) -> Void)? = nil) -> NSApplication.ModalResponse
    {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = message
        alert.informativeText = informative
        for title in buttons {
            alert.addButton(withTitle: title)
        }
        configure?(alert)
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        return alert.runModal()
    }
}

// MARK: - Alert Presentation

@MainActor
extension AppViewModel {
    func presentCoreFailureAlert(
        title: String,
        message: String,
        dedupeKey: String,
        style: NSAlert.Style = .warning)
    {
        let now = Date()
        if self.lastCoreFailureAlertKey == dedupeKey,
           let lastAt = self.lastCoreFailureAlertAt,
           now.timeIntervalSince(lastAt) < self.coreFailureAlertThrottleInterval
        {
            return
        }

        self.lastCoreFailureAlertKey = dedupeKey
        self.lastCoreFailureAlertAt = now

        self.runModalAlert(
            style: style,
            message: title,
            informative: message,
            buttons: [tr("ui.action.ok")])
    }

    func presentConfigValidationFailedAlert(fileName: String, details: String) {
        self.runModalAlert(
            style: .critical,
            message: tr("app.config.validation_failed.title"),
            informative: tr("app.config.validation_failed.message", fileName, details),
            buttons: [tr("ui.action.ok")])
    }

    func presentInitialNoCoreSetupGuideIfNeeded() {
        guard self.shouldPresentInitialNoCoreSetupGuide() else { return }
        guard !didPresentInitialNoCoreSetupGuide else { return }

        didPresentInitialNoCoreSetupGuide = true
        defaults.set(true, forKey: initialNoCoreSetupGuideShownKey)

        let response = self.runModalAlert(
            style: .informational,
            message: tr("app.core.setup_required.title"),
            informative: tr("app.core.setup_required.message", workingDirectoryManager.coreDirectoryURL.path),
            buttons: [tr("ui.action.open_core_directory"), tr("ui.action.ok")])
        if response == .alertFirstButtonReturn {
            self.showCoreDirectoryInFinder()
        }
    }

    func shouldPresentInitialNoCoreSetupGuide() -> Bool {
        guard self.shouldDeferAutoStartForMissingManagedCore() else { return false }
        guard !defaults.bool(forKey: initialNoCoreSetupGuideShownKey) else { return false }
        return true
    }
}
