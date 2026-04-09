import Combine
import Foundation

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published private(set) var display: MenuBarDisplay

    private let session: AppViewModel
    private var cancellable: AnyCancellable?

    init(session: AppViewModel) {
        self.session = session
        self.display = session.menuBarDisplaySnapshot
        self.cancellable = session.$menuBarDisplaySnapshot
            .removeDuplicates()
            .sink { [weak self] display in
                self?.display = display
            }
    }

    var connectionsStore: ConnectionsStore {
        self.session.connectionsStore
    }

    func setPanelPresented(_ presented: Bool) {
        self.session.setPanelVisibility(presented)
    }
}
