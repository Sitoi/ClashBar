import Foundation

@MainActor
struct AppDependencies {
    let processManager: any MihomoControlling
    let coreRepository: any CoreRepository
    let configRepository: any ConfigRepository
    let systemProxyRepository: any SystemProxyRepository
    let tunPermissionRepository: any TunPermissionRepository
    let launchAtLoginRepository: any LaunchAtLoginRepository
    let workingDirectoryManager: WorkingDirectoryManager
    let networkReachabilityMonitor: NetworkReachabilityMonitor
    let ssidMonitorService: SSIDMonitorService
    let remoteMachineStore: RemoteMachineStore
    let proxyGroupIconCache: ProxyGroupIconCache
    let clashbarLogStore: AppLogStore
    let mihomoLogStore: AppLogStore

    static var live: AppDependencies {
        let workingDirectoryManager = WorkingDirectoryManager()
        let processManager = MihomoProcessManager(workingDirectoryManager: workingDirectoryManager)
        let configManager = ConfigDirectoryManager(workingDirectoryManager: workingDirectoryManager)
        let configRepository = DefaultConfigRepository(
            configManager: configManager,
            configImportService: ConfigImportService())
        let sharedSession = URLSessionFactory.makeEphemeralSession(options: .init(
            timeoutIntervalForRequest: 15,
            timeoutIntervalForResource: 30,
            httpMaximumConnectionsPerHost: 4))
        let clashbarLogStore = AppLogStore(
            logFileURL: workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "clashbar.log",
                isDirectory: false))
        let mihomoLogStore = AppLogStore(
            logFileURL: workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "mihomo.log",
                isDirectory: false))

        return AppDependencies(
            processManager: processManager,
            coreRepository: DefaultCoreRepository(processManager: processManager),
            configRepository: configRepository,
            systemProxyRepository: DefaultSystemProxyRepository(service: SystemProxyService()),
            tunPermissionRepository: DefaultTunPermissionRepository(service: TunPermissionService()),
            launchAtLoginRepository: DefaultLaunchAtLoginRepository(service: AppLaunchService()),
            workingDirectoryManager: workingDirectoryManager,
            networkReachabilityMonitor: NetworkReachabilityMonitor(),
            ssidMonitorService: SSIDMonitorService(),
            remoteMachineStore: RemoteMachineStore(session: sharedSession),
            proxyGroupIconCache: ProxyGroupIconCache(
                iconDirectory: workingDirectoryManager.iconDirectoryURL,
                session: sharedSession),
            clashbarLogStore: clashbarLogStore,
            mihomoLogStore: mihomoLogStore)
    }
}
