import Combine
import Foundation

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published private(set) var display: MenuBarDisplay

    private let session: AppViewModel
    private var cancellable: AnyCancellable?

    init(session: AppViewModel) {
        self.session = session
        self.display = Self.makeDisplay(
            baseline: session.menuBarDisplaySnapshot,
            traffic: session.trafficStore.traffic,
            formatter: session.compactMenuBarRate)

        self.cancellable = Publishers.CombineLatest(
            session.$menuBarDisplaySnapshot.removeDuplicates(),
            session.trafficStore.trafficDidChange
                .prepend(session.trafficStore.traffic)
                .removeDuplicates())
            .map { baseline, traffic in
                Self.makeDisplay(
                    baseline: baseline,
                    traffic: traffic,
                    formatter: session.compactMenuBarRate)
            }
            .removeDuplicates()
            .sink { [weak self] in self?.display = $0 }
    }

    func setPanelPresented(_ presented: Bool) {
        self.session.setPanelVisibility(presented)
    }

    private static func makeDisplay(
        baseline: MenuBarDisplay,
        traffic: TrafficSnapshot,
        formatter: (Int64) -> String) -> MenuBarDisplay
    {
        let speedLines: MenuBarSpeedLines? = if baseline.mode == .iconOnly {
            nil
        } else if baseline.isRunning {
            MenuBarSpeedLines(
                up: "\(formatter(max(0, traffic.up)))↑",
                down: "\(formatter(max(0, traffic.down)))↓")
        } else {
            .zero
        }

        return MenuBarDisplay(
            mode: baseline.mode,
            symbolName: baseline.symbolName,
            speedLines: speedLines,
            isRunning: baseline.isRunning,
            isTunEnabled: baseline.isTunEnabled)
    }
}
