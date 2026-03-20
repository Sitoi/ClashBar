import Foundation

struct NormalizeWebSocketPayloadUseCase {
    func execute(message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case let .data(data):
            guard !data.isEmpty else { return nil }
            return data
        case let .string(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed == "null" || trimmed == "{}" {
                return nil
            }
            return Data(trimmed.utf8)
        @unknown default:
            return nil
        }
    }
}
