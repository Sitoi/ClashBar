import Foundation

enum HealthcheckNormalization {
    static func normalizedURL(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func normalizedTimeout(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
