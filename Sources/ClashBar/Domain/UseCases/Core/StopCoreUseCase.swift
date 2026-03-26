import Foundation

@MainActor
struct StopCoreUseCase {
    private let coreRepository: any CoreRepository

    init(coreRepository: any CoreRepository) {
        self.coreRepository = coreRepository
    }

    func execute() async {
        await self.coreRepository.stop()
    }

    func executeImmediately() {
        self.coreRepository.stopImmediately()
    }
}
