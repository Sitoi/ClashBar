@MainActor
extension AppSession {
    func closeAllConnections() async {
        await self.runConnectionMutation(
            actionName: tr("log.action_name.close_all_connections"),
            operation: {
                try await self.makeCloseAllConnectionsUseCase(using: self.clientOrThrow()).execute()
            })
    }

    func closeConnection(id: String) async {
        await self.runConnectionMutation(
            actionName: tr("log.action_name.close_connection", id),
            operation: {
                try await self.makeCloseConnectionUseCase(using: self.clientOrThrow()).execute(id: id)
            })
    }

    func copyAllLogs() {
        self.flushPendingMihomoLogsIfNeeded()
        let content = errorLogs
            .map(formattedLogEntry)
            .joined(separator: "\n")

        copyTextToPasteboard(content)
        appendLog(level: "info", message: tr("log.logs.copied_all", errorLogs.count))
    }

    private func runConnectionMutation(actionName: String, operation: @escaping () async throws -> Void) async {
        // DRY: shared post-mutation refresh flow for connection operations.
        await runNoResponseAction(actionName) {
            try await operation()
            await self.refreshConnections()
        }
    }
}
