import Foundation

struct DecodeStreamLogPayloadUseCase {
    func execute(payload: Data, decoder: JSONDecoder) -> (level: String, message: String)? {
        if let log = try? decoder.decode(LogLine.self, from: payload) {
            let level = (log.type?.isEmpty == false) ? (log.type ?? "info") : "info"
            let message = log.payload?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !message.isEmpty {
                return (level: level, message: message)
            }
        }

        if let response = try? decoder.decode(LogsResponse.self, from: payload),
           let first = response.logs?.first
        {
            let level = (first.type?.isEmpty == false) ? (first.type ?? "info") : "info"
            let message = first.payload?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !message.isEmpty {
                return (level: level, message: message)
            }
        }

        if let text = String(data: payload, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        {
            return (level: "info", message: text)
        }

        return nil
    }
}
