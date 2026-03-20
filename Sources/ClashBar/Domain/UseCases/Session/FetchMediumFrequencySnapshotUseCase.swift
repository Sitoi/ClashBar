import Foundation

struct MediumFrequencySnapshot {
    let versionInfo: VersionInfo
    let configSnapshot: ConfigSnapshot
    let proxyGroupsPayload: ProxyGroupsAndProvidersSnapshot?
}

struct FetchMediumFrequencySnapshotUseCase {
    private let fetchVersionUseCase: FetchVersionUseCase
    private let fetchRuntimeConfigUseCase: FetchRuntimeConfigUseCase
    private let fetchProxyGroupsAndProvidersUseCase: FetchProxyGroupsAndProvidersUseCase?

    init(
        fetchVersionUseCase: FetchVersionUseCase,
        fetchRuntimeConfigUseCase: FetchRuntimeConfigUseCase,
        fetchProxyGroupsAndProvidersUseCase: FetchProxyGroupsAndProvidersUseCase?)
    {
        self.fetchVersionUseCase = fetchVersionUseCase
        self.fetchRuntimeConfigUseCase = fetchRuntimeConfigUseCase
        self.fetchProxyGroupsAndProvidersUseCase = fetchProxyGroupsAndProvidersUseCase
    }

    func execute() async throws -> MediumFrequencySnapshot {
        async let versionTask = self.fetchVersionUseCase.execute()
        async let configTask = self.fetchRuntimeConfigUseCase.execute()

        if let fetchProxyGroupsAndProvidersUseCase {
            async let proxyGroupsTask = fetchProxyGroupsAndProvidersUseCase.execute()
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
