import Foundation

enum AppLogSource: String, Codable, Equatable, CaseIterable, Identifiable {
    case clashbar
    case mihomo

    var id: String {
        rawValue
    }
}

struct AppErrorLogEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let source: AppLogSource
    let level: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: AppLogSource = .clashbar,
        level: String,
        message: String)
    {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.level = level
        self.message = message
    }
}

struct LogsResponse: Codable, Equatable {
    let logs: [LogLine]?
}

struct LogLine: Codable, Equatable {
    let type: String?
    let payload: String?
}

struct DelayMeasurement: Decodable, Equatable {
    let value: Int?

    private enum CodingKeys: String, CodingKey {
        case delay
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let value = try container.decodeIfPresent(Int.self, forKey: .delay)
        {
            self.value = value
            return
        }

        let container = try decoder.singleValueContainer()
        self.value = try? container.decode([String: Int].self).values.first
    }
}

struct GroupDelayMeasurement: Decodable, Equatable {
    let values: [String: Int]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = (try? container.decode([String: Int].self)) ?? [:]
    }
}
