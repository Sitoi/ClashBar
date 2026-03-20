import Foundation

struct DetermineDataAcquisitionPolicyUseCase {
    func execute(
        panelPresented: Bool,
        activeTab: RootTab,
        statusBarDisplayMode: StatusBarDisplayMode,
        foregroundMediumFrequencyIntervalNanoseconds: UInt64,
        backgroundMediumFrequencyIntervalNanoseconds: UInt64,
        foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: UInt64,
        foregroundLowFrequencyOtherTabsIntervalNanoseconds: UInt64,
        backgroundLowFrequencyIntervalNanoseconds: UInt64) -> DataAcquisitionPolicy
    {
        let trafficEnabled = panelPresented || statusBarDisplayMode != .iconOnly

        if !panelPresented {
            return DataAcquisitionPolicy(
                enableTrafficStream: trafficEnabled,
                enableMemoryStream: false,
                enableConnectionsStream: false,
                connectionsIntervalMilliseconds: nil,
                enableLogsStream: false,
                mediumFrequencyIntervalNanoseconds: backgroundMediumFrequencyIntervalNanoseconds,
                lowFrequencyIntervalNanoseconds: backgroundLowFrequencyIntervalNanoseconds)
        }

        let lowFrequencyInterval: UInt64 = switch activeTab {
        case .proxy, .rules:
            foregroundLowFrequencyPrimaryTabsIntervalNanoseconds
        default:
            foregroundLowFrequencyOtherTabsIntervalNanoseconds
        }

        let memoryEnabled = activeTab == .proxy
        let connectionsEnabled = activeTab == .proxy || activeTab == .connections
        let logsEnabled = activeTab == .logs

        return DataAcquisitionPolicy(
            enableTrafficStream: trafficEnabled,
            enableMemoryStream: memoryEnabled,
            enableConnectionsStream: connectionsEnabled,
            connectionsIntervalMilliseconds: connectionsEnabled ? 1000 : nil,
            enableLogsStream: logsEnabled,
            mediumFrequencyIntervalNanoseconds: foregroundMediumFrequencyIntervalNanoseconds,
            lowFrequencyIntervalNanoseconds: lowFrequencyInterval)
    }
}
