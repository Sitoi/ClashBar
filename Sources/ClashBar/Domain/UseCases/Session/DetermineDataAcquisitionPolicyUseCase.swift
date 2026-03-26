import Foundation

struct DetermineDataAcquisitionPolicyUseCase {
    struct Input {
        let panelPresented: Bool
        let activeTab: RootTab
        let statusBarDisplayMode: StatusBarDisplayMode
        let foregroundMediumFrequencyIntervalNanoseconds: UInt64
        let backgroundMediumFrequencyIntervalNanoseconds: UInt64
        let foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: UInt64
        let foregroundLowFrequencyOtherTabsIntervalNanoseconds: UInt64
        let backgroundLowFrequencyIntervalNanoseconds: UInt64
    }

    func execute(_ input: Input) -> DataAcquisitionPolicy {
        let trafficEnabled = input.panelPresented || input.statusBarDisplayMode != .iconOnly

        if !input.panelPresented {
            return DataAcquisitionPolicy(
                enableTrafficStream: trafficEnabled,
                enableMemoryStream: false,
                enableConnectionsStream: false,
                connectionsIntervalMilliseconds: nil,
                enableLogsStream: false,
                mediumFrequencyIntervalNanoseconds: input.backgroundMediumFrequencyIntervalNanoseconds,
                lowFrequencyIntervalNanoseconds: input.backgroundLowFrequencyIntervalNanoseconds)
        }

        let lowFrequencyInterval: UInt64 = switch input.activeTab {
        case .proxy, .rules:
            input.foregroundLowFrequencyPrimaryTabsIntervalNanoseconds
        default:
            input.foregroundLowFrequencyOtherTabsIntervalNanoseconds
        }

        let memoryEnabled = input.activeTab == .proxy
        let connectionsEnabled = input.activeTab == .proxy || input.activeTab == .connections
        let logsEnabled = input.activeTab == .logs

        return DataAcquisitionPolicy(
            enableTrafficStream: trafficEnabled,
            enableMemoryStream: memoryEnabled,
            enableConnectionsStream: connectionsEnabled,
            connectionsIntervalMilliseconds: connectionsEnabled ? 1000 : nil,
            enableLogsStream: logsEnabled,
            mediumFrequencyIntervalNanoseconds: input.foregroundMediumFrequencyIntervalNanoseconds,
            lowFrequencyIntervalNanoseconds: lowFrequencyInterval)
    }
}
