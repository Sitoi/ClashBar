import Foundation

struct PatchRuntimeConfigUseCase {
    private let repository: any RuntimeConfigRepository

    init(repository: any RuntimeConfigRepository) {
        self.repository = repository
    }

    func execute(body: [String: JSONValue]) async throws {
        try await self.repository.patchConfig(body: body)
    }
}
