import Foundation

@MainActor
extension AppSession {
    func runRefresh(_ block: () async throws -> Void) async {
        do {
            ensureAPIClient()
            try await block()
            apiStatus = .healthy
        } catch {
            apiStatus = .degraded
            appendLog(level: "error", message: error.localizedDescription)
        }
    }

    func runNoResponseAction(_ name: String, operation: () async throws -> Void) async {
        do {
            ensureAPIClient()
            try await operation()
            appendLog(level: "info", message: tr("log.action.success", name))
        } catch {
            appendLog(level: "error", message: tr("log.action.failed", name, error.localizedDescription))
        }
    }
}
