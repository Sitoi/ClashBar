import Foundation

@MainActor
struct ClearSystemProxyBlockingUseCase {
    private let repository: any SystemProxyRepository

    init(repository: any SystemProxyRepository) {
        self.repository = repository
    }

    func execute(timeout: TimeInterval = 2.0) {
        self.repository.clearBlocking(timeout: timeout)
    }
}
