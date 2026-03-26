import Foundation

enum InsightsTimeWindow: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case oneHour
    case fourHours
    case oneDay
    case runtime

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .fifteenMinutes:
            "ui.insights.window.15m"
        case .oneHour:
            "ui.insights.window.1h"
        case .fourHours:
            "ui.insights.window.4h"
        case .oneDay:
            "ui.insights.window.1d"
        case .runtime:
            "ui.insights.window.run"
        }
    }

    var minuteCount: Int? {
        switch self {
        case .fifteenMinutes:
            15
        case .oneHour:
            60
        case .fourHours:
            240
        case .oneDay:
            1440
        case .runtime:
            nil
        }
    }
}

enum InsightsViewMode: String, CaseIterable, Identifiable {
    case overview
    case domains
    case rules
    case routes

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .overview:
            "ui.insights.view.overview"
        case .domains:
            "ui.insights.view.domains"
        case .rules:
            "ui.insights.view.rules"
        case .routes:
            "ui.insights.view.routes"
        }
    }
}

struct TrafficInsightFacetEntry: Codable, Equatable, Identifiable {
    let id: String
    let domain: String
    let rule: String
    let route: String
    var upload: Int64
    var download: Int64
    var lastSeenAt: TimeInterval

    var total: Int64 {
        self.upload + self.download
    }
}

struct TrafficInsightsMinuteBucket: Codable, Equatable, Identifiable {
    let minuteStart: Int64
    var upload: Int64
    var download: Int64
    var entries: [String: TrafficInsightFacetEntry]

    var id: Int64 {
        minuteStart
    }

    var total: Int64 {
        self.upload + self.download
    }
}

struct TrafficInsightsTrendPoint: Equatable, Identifiable {
    let minuteStart: Int64
    let upload: Int64
    let download: Int64

    var id: Int64 {
        minuteStart
    }
}

struct TrafficInsightsDomainItem: Equatable, Identifiable {
    let domain: String
    let upload: Int64
    let download: Int64
    let uniqueRuleCount: Int
    let uniqueRouteCount: Int
    let topRule: String
    let topRoute: String
    let lastSeenAt: TimeInterval

    var id: String {
        domain
    }

    var total: Int64 {
        self.upload + self.download
    }
}

struct TrafficInsightsRuleItem: Equatable, Identifiable {
    let rule: String
    let upload: Int64
    let download: Int64
    let uniqueDomainCount: Int
    let uniqueRouteCount: Int
    let topDomain: String
    let topRoute: String
    let lastSeenAt: TimeInterval

    var id: String {
        rule
    }

    var total: Int64 {
        self.upload + self.download
    }
}

struct TrafficInsightsRouteItem: Equatable, Identifiable {
    let route: String
    let upload: Int64
    let download: Int64
    let uniqueDomainCount: Int
    let uniqueRuleCount: Int
    let topDomain: String
    let topRule: String
    let lastSeenAt: TimeInterval

    var id: String {
        route
    }

    var total: Int64 {
        self.upload + self.download
    }
}

struct TrafficInsightsSnapshot: Equatable {
    let window: InsightsTimeWindow
    let totalUpload: Int64
    let totalDownload: Int64
    let domainItems: [TrafficInsightsDomainItem]
    let ruleItems: [TrafficInsightsRuleItem]
    let routeItems: [TrafficInsightsRouteItem]
    let trendPoints: [TrafficInsightsTrendPoint]

    var totalBytes: Int64 {
        self.totalUpload + self.totalDownload
    }
}
