import Foundation

struct MediumFrequencySnapshot {
    let versionInfo: VersionInfo
    let configSnapshot: ConfigSnapshot
    let proxyGroupsPayload: ProxyGroupsAndProvidersSnapshot?
}

struct FetchMediumFrequencySnapshotUseCase {
    private let transport: any MihomoAPITransporting
    private let includeProxyGroups: Bool

    init(transport: any MihomoAPITransporting, includeProxyGroups: Bool) {
        self.transport = transport
        self.includeProxyGroups = includeProxyGroups
    }

    func execute() async throws -> MediumFrequencySnapshot {
        async let versionTask: VersionInfo = self.transport.request(.version)
        async let configTask: ConfigSnapshot = self.transport.request(.getConfigs)

        if self.includeProxyGroups {
            async let proxyGroupsTask = FetchProxyGroupsAndProvidersUseCase(transport: self.transport).execute()
            let (versionInfo, configSnapshot, proxyGroupsPayload) = try await (
                versionTask,
                configTask,
                proxyGroupsTask)
            return MediumFrequencySnapshot(
                versionInfo: versionInfo,
                configSnapshot: configSnapshot,
                proxyGroupsPayload: proxyGroupsPayload)
        }

        let (versionInfo, configSnapshot) = try await (versionTask, configTask)
        return MediumFrequencySnapshot(
            versionInfo: versionInfo,
            configSnapshot: configSnapshot,
            proxyGroupsPayload: nil)
    }
}
