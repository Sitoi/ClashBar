import Foundation

@MainActor
extension AppSession {
    func makeDetermineDataAcquisitionPolicyUseCase() -> DetermineDataAcquisitionPolicyUseCase {
        DetermineDataAcquisitionPolicyUseCase()
    }

    func makeRuntimeConfigRepository(using transport: any MihomoAPITransporting) -> RuntimeConfigRepository {
        DefaultRuntimeConfigRepository(transport: transport)
    }

    func makeFetchRuntimeConfigUseCase(using transport: any MihomoAPITransporting) -> FetchRuntimeConfigUseCase {
        FetchRuntimeConfigUseCase(repository: self.makeRuntimeConfigRepository(using: transport))
    }

    func makePatchRuntimeConfigUseCase(using transport: any MihomoAPITransporting) -> PatchRuntimeConfigUseCase {
        PatchRuntimeConfigUseCase(repository: self.makeRuntimeConfigRepository(using: transport))
    }

    func makeReloadRuntimeConfigUseCase(using transport: any MihomoAPITransporting) -> ReloadRuntimeConfigUseCase {
        ReloadRuntimeConfigUseCase(repository: self.makeRuntimeConfigRepository(using: transport))
    }

    func makeMaintenanceRepository(using transport: any MihomoAPITransporting) -> MaintenanceRepository {
        DefaultMaintenanceRepository(transport: transport)
    }

    func makeFetchVersionUseCase(using transport: any MihomoAPITransporting) -> FetchVersionUseCase {
        FetchVersionUseCase(repository: self.makeMaintenanceRepository(using: transport))
    }

    func makeConnectionsRepository(using transport: any MihomoAPITransporting) -> ConnectionsRepository {
        DefaultConnectionsRepository(transport: transport)
    }

    func makeCloseAllConnectionsUseCase(using transport: any MihomoAPITransporting) -> CloseAllConnectionsUseCase {
        CloseAllConnectionsUseCase(repository: self.makeConnectionsRepository(using: transport))
    }

    func makeCloseConnectionUseCase(using transport: any MihomoAPITransporting) -> CloseConnectionUseCase {
        CloseConnectionUseCase(repository: self.makeConnectionsRepository(using: transport))
    }

    func makeProxyGroupsRepository(using transport: any MihomoAPITransporting) -> ProxyGroupsRepository {
        DefaultProxyGroupsRepository(transport: transport)
    }

    func makeProvidersRepository(using transport: any MihomoAPITransporting) -> ProvidersRepository {
        DefaultProvidersRepository(transport: transport)
    }

    func makeFetchProxyGroupsAndProvidersUseCase(
        using transport: any MihomoAPITransporting) -> FetchProxyGroupsAndProvidersUseCase
    {
        FetchProxyGroupsAndProvidersUseCase(
            proxyGroupsRepository: self.makeProxyGroupsRepository(using: transport),
            providersRepository: self.makeProvidersRepository(using: transport))
    }

    func makeFetchMediumFrequencySnapshotUseCase(
        using transport: any MihomoAPITransporting,
        includeProxyGroups: Bool) -> FetchMediumFrequencySnapshotUseCase
    {
        FetchMediumFrequencySnapshotUseCase(
            fetchVersionUseCase: self.makeFetchVersionUseCase(using: transport),
            fetchRuntimeConfigUseCase: self.makeFetchRuntimeConfigUseCase(using: transport),
            fetchProxyGroupsAndProvidersUseCase: includeProxyGroups
                ? self.makeFetchProxyGroupsAndProvidersUseCase(using: transport)
                : nil)
    }

    func makeBuildProxyGroupsPresentationUseCase() -> BuildProxyGroupsPresentationUseCase {
        BuildProxyGroupsPresentationUseCase()
    }
}
