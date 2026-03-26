import Foundation

struct ResolveEffectiveMixedPortUseCase {
    func execute(runtimeMixedPort: Int, settingsMixedPort: String, fallback: Int = 7890) -> Int {
        if runtimeMixedPort > 0 {
            return runtimeMixedPort
        }

        let trimmed = settingsMixedPort.trimmed
        if let value = Int(trimmed), (1...65535).contains(value) {
            return value
        }

        return fallback
    }
}
