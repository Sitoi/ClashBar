import Foundation

struct RemoteConfigSubscription: Codable, Equatable {
    let urlString: String
    var autoUpdateEnabled: Bool
    var autoUpdateIntervalHours: Int
    var lastUpdateCheckAt: Date?

    static let defaultAutoUpdateIntervalHours = 6
    static let minimumAutoUpdateIntervalHours = 1

    init(
        urlString: String,
        autoUpdateEnabled: Bool = false,
        autoUpdateIntervalHours: Int = defaultAutoUpdateIntervalHours,
        lastUpdateCheckAt: Date? = nil)
    {
        self.urlString = urlString
        self.autoUpdateEnabled = autoUpdateEnabled
        self.autoUpdateIntervalHours = max(Self.minimumAutoUpdateIntervalHours, autoUpdateIntervalHours)
        self.lastUpdateCheckAt = lastUpdateCheckAt
    }

    /// When the next auto-update check should run. Returns nil if auto-update is disabled or never checked.
    func nextUpdateAt() -> Date? {
        guard self.autoUpdateEnabled, let lastCheck = lastUpdateCheckAt else { return nil }
        return self.nextUpdateDate(from: lastCheck)
    }

    /// Whether this subscription is due for an auto-update check.
    func isDue(now: Date = Date()) -> Bool {
        guard self.autoUpdateEnabled else { return false }
        guard let nextUpdateAt = self.nextUpdateAt() else { return true }
        return now >= nextUpdateAt
    }

    func markChecked(at date: Date = Date()) -> RemoteConfigSubscription {
        RemoteConfigSubscription(
            urlString: self.urlString,
            autoUpdateEnabled: self.autoUpdateEnabled,
            autoUpdateIntervalHours: self.autoUpdateIntervalHours,
            lastUpdateCheckAt: date)
    }

    private func nextUpdateDate(from lastCheck: Date) -> Date {
        lastCheck.addingTimeInterval(TimeInterval(self.autoUpdateIntervalHours) * 3600)
    }
}
