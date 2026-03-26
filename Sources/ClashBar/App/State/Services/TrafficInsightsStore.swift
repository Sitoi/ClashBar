import Foundation

@MainActor
final class TrafficInsightsStore: ObservableObject {
    @Published private(set) var lastUpdatedAt: Date = .distantPast
    @Published private(set) var displayReferenceDate: Date = Date()

    private struct PersistedState: Codable {
        let buckets: [TrafficInsightsMinuteBucket]
        let hourlyTrendBuckets: [TrafficTotalsBucket]
        let dailyTrendBuckets: [TrafficTotalsBucket]
        let cumulativeEntries: [TrafficInsightFacetEntry]
        let cumulativeUpload: Int64
        let cumulativeDownload: Int64

        init(
            buckets: [TrafficInsightsMinuteBucket],
            hourlyTrendBuckets: [TrafficTotalsBucket] = [],
            dailyTrendBuckets: [TrafficTotalsBucket] = [],
            cumulativeEntries: [TrafficInsightFacetEntry] = [],
            cumulativeUpload: Int64 = 0,
            cumulativeDownload: Int64 = 0)
        {
            self.buckets = buckets
            self.hourlyTrendBuckets = hourlyTrendBuckets
            self.dailyTrendBuckets = dailyTrendBuckets
            self.cumulativeEntries = cumulativeEntries
            self.cumulativeUpload = cumulativeUpload
            self.cumulativeDownload = cumulativeDownload
        }

        private enum CodingKeys: String, CodingKey {
            case buckets
            case hourlyTrendBuckets
            case dailyTrendBuckets
            case cumulativeEntries
            case cumulativeUpload
            case cumulativeDownload
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.buckets = try container.decodeIfPresent(
                [TrafficInsightsMinuteBucket].self,
                forKey: .buckets) ?? []
            self.hourlyTrendBuckets = try container.decodeIfPresent(
                [TrafficTotalsBucket].self,
                forKey: .hourlyTrendBuckets) ?? []
            self.dailyTrendBuckets = try container.decodeIfPresent(
                [TrafficTotalsBucket].self,
                forKey: .dailyTrendBuckets) ?? []
            self.cumulativeEntries = try container.decodeIfPresent(
                [TrafficInsightFacetEntry].self,
                forKey: .cumulativeEntries) ?? []
            self.cumulativeUpload = try container.decodeIfPresent(
                Int64.self,
                forKey: .cumulativeUpload) ?? 0
            self.cumulativeDownload = try container.decodeIfPresent(
                Int64.self,
                forKey: .cumulativeDownload) ?? 0
        }
    }

    private struct ConnectionBaseline {
        var upload: Int64
        var download: Int64
    }

    private struct TrafficTotalsBaseline {
        var upload: Int64
        var download: Int64
    }

    private struct TrafficTotalsBucket: Codable, Equatable, Identifiable {
        let bucketStart: Int64
        var upload: Int64
        var download: Int64

        var id: Int64 {
            self.bucketStart
        }
    }

    private let storageURL: URL
    private let maxPersistedMinutes = 60 * 24
    private let maxPersistedHours = 24 * 180
    private let maxRuntimeTrendPoints = 240
    private var persistedBuckets: [Int64: TrafficInsightsMinuteBucket] = [:]
    private var hourlyTrendBuckets: [Int64: TrafficTotalsBucket] = [:]
    private var dailyTrendBuckets: [Int64: TrafficTotalsBucket] = [:]
    private var cumulativeEntries: [String: TrafficInsightFacetEntry] = [:]
    private var cumulativeUpload: Int64 = 0
    private var cumulativeDownload: Int64 = 0
    private var baselines: [String: ConnectionBaseline] = [:]
    private var trafficTotalsBaseline: TrafficTotalsBaseline?
    private var persistTask: Task<Void, Never>?
    private var displayClockTask: Task<Void, Never>?
    private let launchTime = Date()

    init(storageURL: URL) {
        self.storageURL = storageURL
        self.loadPersistedStateIfAvailable()
        self.trimPersistedBuckets(now: Date())
        self.trimHourlyTrendBuckets(now: Date())
        self.startDisplayClock()
    }

    func ingest(snapshot: ConnectionsSnapshot, recordedAt: Date = Date()) {
        let visibleIDs = Set(snapshot.connections.map(\.id))

        for connection in snapshot.connections {
            let upload = max(0, connection.upload ?? 0)
            let download = max(0, connection.download ?? 0)
            let previous = self.baselines[connection.id]

            let deltaUpload: Int64
            let deltaDownload: Int64
            if let previous {
                deltaUpload = max(0, upload - previous.upload)
                deltaDownload = max(0, download - previous.download)
            } else {
                let shouldCountInitial = self.shouldCountInitialTraffic(for: connection, now: recordedAt)
                deltaUpload = shouldCountInitial ? upload : 0
                deltaDownload = shouldCountInitial ? download : 0
            }

            self.baselines[connection.id] = ConnectionBaseline(upload: upload, download: download)

            guard deltaUpload > 0 || deltaDownload > 0 else { continue }
            self.recordDelta(
                domain: self.normalizedDomain(for: connection),
                rule: self.normalizedRule(for: connection),
                route: self.normalizedRoute(for: connection),
                upload: deltaUpload,
                download: deltaDownload,
                recordedAt: recordedAt)
        }

        if self.baselines.count != visibleIDs.count {
            self.baselines = self.baselines.filter { visibleIDs.contains($0.key) }
        }
    }

    func clearConnectionBaselines() {
        self.baselines.removeAll(keepingCapacity: false)
    }

    func clearTrafficTotalsBaseline() {
        self.trafficTotalsBaseline = nil
    }

    func resetAllStatistics() {
        self.persistTask?.cancel()
        self.persistTask = nil
        self.persistedBuckets.removeAll(keepingCapacity: false)
        self.hourlyTrendBuckets.removeAll(keepingCapacity: false)
        self.dailyTrendBuckets.removeAll(keepingCapacity: false)
        self.cumulativeEntries.removeAll(keepingCapacity: false)
        self.cumulativeUpload = 0
        self.cumulativeDownload = 0
        self.baselines.removeAll(keepingCapacity: false)
        self.trafficTotalsBaseline = nil
        self.lastUpdatedAt = Date()
        self.displayReferenceDate = Date()
        try? FileManager.default.removeItem(at: self.storageURL)
    }

    func snapshot(for window: InsightsTimeWindow, now: Date = Date()) -> TrafficInsightsSnapshot {
        let effectiveNow = now
        switch window {
        case .runtime:
            return self.makeSnapshot(
                window: window,
                totalUpload: self.cumulativeUpload,
                totalDownload: self.cumulativeDownload,
                entries: Array(self.cumulativeEntries.values),
                trendPoints: self.makeRuntimeTrendPoints(now: effectiveNow))
        default:
            let cutoff = Int64(effectiveNow.timeIntervalSince1970) - Int64((window.minuteCount ?? 0) * 60)
            let buckets = self.persistedBuckets.values
                .filter { $0.minuteStart >= cutoff }
                .sorted { $0.minuteStart < $1.minuteStart }
            return self.makeSnapshot(window: window, buckets: buckets)
        }
    }

    func flushPersistence() {
        self.persistTask?.cancel()
        self.persistTask = nil
        self.persistState()
    }

    func ingestTrafficSnapshot(_ snapshot: TrafficSnapshot, recordedAt: Date = Date()) {
        guard let upTotal = snapshot.upTotal, let downTotal = snapshot.downTotal else { return }

        let normalizedUpload = max(0, upTotal)
        let normalizedDownload = max(0, downTotal)

        guard let baseline = self.trafficTotalsBaseline else {
            self.trafficTotalsBaseline = TrafficTotalsBaseline(
                upload: normalizedUpload,
                download: normalizedDownload)
            self.displayReferenceDate = recordedAt
            return
        }

        let deltaUpload = normalizedUpload >= baseline.upload ? (normalizedUpload - baseline.upload) : 0
        let deltaDownload = normalizedDownload >= baseline.download ? (normalizedDownload - baseline.download) : 0
        self.trafficTotalsBaseline = TrafficTotalsBaseline(
            upload: normalizedUpload,
            download: normalizedDownload)

        guard deltaUpload > 0 || deltaDownload > 0 else {
            self.displayReferenceDate = recordedAt
            return
        }

        self.recordTrafficDelta(
            upload: deltaUpload,
            download: deltaDownload,
            recordedAt: recordedAt)
    }

    private func shouldCountInitialTraffic(for connection: ConnectionSummary, now: Date) -> Bool {
        guard let startTimestamp = connection.startTimestamp else { return false }
        return startTimestamp >= self.launchTime.addingTimeInterval(-2).timeIntervalSince1970
            && startTimestamp <= now.timeIntervalSince1970 + 2
    }

    private func normalizedDomain(for connection: ConnectionSummary) -> String {
        if let host = connection.metadata?.host?.trimmedNonEmpty {
            return host
        }
        if let destinationIP = connection.metadata?.destinationIP?.trimmedNonEmpty {
            return destinationIP
        }
        return "Unknown"
    }

    private func normalizedRule(for connection: ConnectionSummary) -> String {
        let type = connection.rule?.trimmedNonEmpty ?? "MATCH"
        let payload = connection.rulePayload?.trimmedNonEmpty
        guard let payload else { return type }
        return "\(type):\(payload)"
    }

    private func normalizedRoute(for connection: ConnectionSummary) -> String {
        let parts = (connection.chains ?? []).compactMap(\.trimmedNonEmpty).reversed()
        let route = parts.joined(separator: " > ")
        return route.isEmpty ? "UNKNOWN" : route
    }

    private func recordDelta(
        domain: String,
        rule: String,
        route: String,
        upload: Int64,
        download: Int64,
        recordedAt: Date)
    {
        let minuteStart = Int64(recordedAt.timeIntervalSince1970 / 60) * 60
        let entryID = self.entryID(domain: domain, rule: rule, route: route)
        let timestamp = recordedAt.timeIntervalSince1970

        self.updateEntries(
            bucketMap: &self.persistedBuckets,
            minuteStart: minuteStart,
            entryID: entryID,
            domain: domain,
            rule: rule,
            route: route,
            upload: upload,
            download: download,
            timestamp: timestamp)
        self.updateCumulativeEntry(
            entryID: entryID,
            domain: domain,
            rule: rule,
            route: route,
            upload: upload,
            download: download,
            timestamp: timestamp)
        self.displayReferenceDate = recordedAt
        self.schedulePersistence()
    }

    private func recordTrafficDelta(
        upload: Int64,
        download: Int64,
        recordedAt: Date)
    {
        let minuteStart = Int64(recordedAt.timeIntervalSince1970 / 60) * 60
        self.updateTrafficTotals(
            bucketMap: &self.persistedBuckets,
            minuteStart: minuteStart,
            upload: upload,
            download: download)
        self.updateTrendBucket(
            bucketMap: &self.hourlyTrendBuckets,
            bucketStart: Int64(recordedAt.timeIntervalSince1970 / 3600) * 3600,
            upload: upload,
            download: download)
        self.updateTrendBucket(
            bucketMap: &self.dailyTrendBuckets,
            bucketStart: Int64(recordedAt.timeIntervalSince1970 / 86_400) * 86_400,
            upload: upload,
            download: download)
        self.cumulativeUpload += upload
        self.cumulativeDownload += download
        self.trimPersistedBuckets(now: recordedAt)
        self.trimHourlyTrendBuckets(now: recordedAt)
        self.lastUpdatedAt = recordedAt
        self.displayReferenceDate = recordedAt
        self.schedulePersistence()
    }

    private func updateEntries(
        bucketMap: inout [Int64: TrafficInsightsMinuteBucket],
        minuteStart: Int64,
        entryID: String,
        domain: String,
        rule: String,
        route: String,
        upload: Int64,
        download: Int64,
        timestamp: TimeInterval)
    {
        var bucket = bucketMap[minuteStart] ?? TrafficInsightsMinuteBucket(
            minuteStart: minuteStart,
            upload: 0,
            download: 0,
            entries: [:])

        var entry = bucket.entries[entryID] ?? TrafficInsightFacetEntry(
            id: entryID,
            domain: domain,
            rule: rule,
            route: route,
            upload: 0,
            download: 0,
            lastSeenAt: timestamp)
        entry.upload += upload
        entry.download += download
        entry.lastSeenAt = max(entry.lastSeenAt, timestamp)
        bucket.entries[entryID] = entry
        bucketMap[minuteStart] = bucket
    }

    private func updateTrafficTotals(
        bucketMap: inout [Int64: TrafficInsightsMinuteBucket],
        minuteStart: Int64,
        upload: Int64,
        download: Int64)
    {
        var bucket = bucketMap[minuteStart] ?? TrafficInsightsMinuteBucket(
            minuteStart: minuteStart,
            upload: 0,
            download: 0,
            entries: [:])
        bucket.upload += upload
        bucket.download += download
        bucketMap[minuteStart] = bucket
    }

    private func updateTrendBucket(
        bucketMap: inout [Int64: TrafficTotalsBucket],
        bucketStart: Int64,
        upload: Int64,
        download: Int64)
    {
        var bucket = bucketMap[bucketStart] ?? TrafficTotalsBucket(
            bucketStart: bucketStart,
            upload: 0,
            download: 0)
        bucket.upload += upload
        bucket.download += download
        bucketMap[bucketStart] = bucket
    }

    private func trimPersistedBuckets(now: Date) {
        let cutoff = Int64(now.timeIntervalSince1970) - Int64(self.maxPersistedMinutes * 60)
        self.persistedBuckets = self.persistedBuckets.filter { $0.key >= cutoff }
    }

    private func trimHourlyTrendBuckets(now: Date) {
        let cutoff = Int64(now.timeIntervalSince1970) - Int64(self.maxPersistedHours * 3600)
        self.hourlyTrendBuckets = self.hourlyTrendBuckets.filter { $0.key >= cutoff }
    }

    private func updateCumulativeEntry(
        entryID: String,
        domain: String,
        rule: String,
        route: String,
        upload: Int64,
        download: Int64,
        timestamp: TimeInterval)
    {
        var entry = self.cumulativeEntries[entryID] ?? TrafficInsightFacetEntry(
            id: entryID,
            domain: domain,
            rule: rule,
            route: route,
            upload: 0,
            download: 0,
            lastSeenAt: timestamp)
        entry.upload += upload
        entry.download += download
        entry.lastSeenAt = max(entry.lastSeenAt, timestamp)
        self.cumulativeEntries[entryID] = entry
    }

    private func startDisplayClock() {
        self.displayClockTask?.cancel()
        self.displayClockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                } catch {
                    return
                }
                guard let self else { return }
                self.displayReferenceDate = Date()
            }
        }
    }

    private func schedulePersistence() {
        self.persistTask?.cancel()
        self.persistTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            guard let self else { return }
            self.persistState()
        }
    }

    private func persistState() {
        let directory = self.storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let buckets = self.persistedBuckets.values.sorted { $0.minuteStart < $1.minuteStart }
        let hourlyTrendBuckets = self.hourlyTrendBuckets.values.sorted { $0.bucketStart < $1.bucketStart }
        let dailyTrendBuckets = self.dailyTrendBuckets.values.sorted { $0.bucketStart < $1.bucketStart }
        let cumulativeEntries = self.cumulativeEntries.values.sorted { lhs, rhs in
            lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
        let state = PersistedState(
            buckets: buckets,
            hourlyTrendBuckets: hourlyTrendBuckets,
            dailyTrendBuckets: dailyTrendBuckets,
            cumulativeEntries: cumulativeEntries,
            cumulativeUpload: self.cumulativeUpload,
            cumulativeDownload: self.cumulativeDownload)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: self.storageURL, options: .atomic)
    }

    private func loadPersistedStateIfAvailable() {
        guard let data = try? Data(contentsOf: self.storageURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return
        }

        self.persistedBuckets = Dictionary(uniqueKeysWithValues: state.buckets.map { ($0.minuteStart, $0) })
        self.hourlyTrendBuckets = Dictionary(uniqueKeysWithValues: state.hourlyTrendBuckets.map { ($0.bucketStart, $0) })
        self.dailyTrendBuckets = Dictionary(uniqueKeysWithValues: state.dailyTrendBuckets.map { ($0.bucketStart, $0) })
        self.cumulativeEntries = Dictionary(uniqueKeysWithValues: state.cumulativeEntries.map { ($0.id, $0) })
        self.cumulativeUpload = state.cumulativeUpload
        self.cumulativeDownload = state.cumulativeDownload
        let didBackfillTrendBuckets = self.backfillTrendBucketsIfNeeded()
        let didBackfillCumulative = self.reconcileCumulativeStateWithPersistedBuckets()
        let latestMinuteBucket = state.buckets.map(\.minuteStart).max().map(TimeInterval.init) ?? 0
        let latestHourBucket = state.hourlyTrendBuckets.map(\.bucketStart).max().map(TimeInterval.init) ?? 0
        let latestDayBucket = state.dailyTrendBuckets.map(\.bucketStart).max().map(TimeInterval.init) ?? 0
        let latestCumulativeEntry = self.cumulativeEntries.values.map(\.lastSeenAt).max() ?? 0
        self.lastUpdatedAt = Date(
            timeIntervalSince1970: max(
                latestMinuteBucket,
                latestHourBucket,
                latestDayBucket,
                latestCumulativeEntry))
        if didBackfillTrendBuckets || didBackfillCumulative {
            self.persistState()
        }
    }

    private func backfillTrendBucketsIfNeeded() -> Bool {
        guard self.hourlyTrendBuckets.isEmpty && self.dailyTrendBuckets.isEmpty else { return false }

        for bucket in self.persistedBuckets.values {
            let timestamp = bucket.minuteStart
            self.updateTrendBucket(
                bucketMap: &self.hourlyTrendBuckets,
                bucketStart: Int64(timestamp / 3600) * 3600,
                upload: bucket.upload,
                download: bucket.download)
            self.updateTrendBucket(
                bucketMap: &self.dailyTrendBuckets,
                bucketStart: Int64(timestamp / 86_400) * 86_400,
                upload: bucket.upload,
                download: bucket.download)
        }

        return !self.persistedBuckets.isEmpty
    }

    private func reconcileCumulativeStateWithPersistedBuckets() -> Bool {
        guard !self.persistedBuckets.isEmpty else { return false }
        var changed = false
        var bucketEntries: [String: TrafficInsightFacetEntry] = [:]

        for bucket in self.persistedBuckets.values {
            for entry in bucket.entries.values {
                var accumulated = bucketEntries[entry.id] ?? TrafficInsightFacetEntry(
                    id: entry.id,
                    domain: entry.domain,
                    rule: entry.rule,
                    route: entry.route,
                    upload: 0,
                    download: 0,
                    lastSeenAt: entry.lastSeenAt)
                accumulated.upload += entry.upload
                accumulated.download += entry.download
                accumulated.lastSeenAt = max(accumulated.lastSeenAt, entry.lastSeenAt)
                bucketEntries[entry.id] = accumulated
            }
        }

        for (id, bucketEntry) in bucketEntries {
            if var current = self.cumulativeEntries[id] {
                let nextUpload = max(current.upload, bucketEntry.upload)
                let nextDownload = max(current.download, bucketEntry.download)
                let nextLastSeen = max(current.lastSeenAt, bucketEntry.lastSeenAt)
                if nextUpload != current.upload || nextDownload != current.download || nextLastSeen != current.lastSeenAt {
                    current.upload = nextUpload
                    current.download = nextDownload
                    current.lastSeenAt = nextLastSeen
                    self.cumulativeEntries[id] = current
                    changed = true
                }
            } else {
                self.cumulativeEntries[id] = bucketEntry
                changed = true
            }
        }

        let bucketUploadTotal = self.persistedBuckets.values.reduce(0) { $0 + $1.upload }
        let bucketDownloadTotal = self.persistedBuckets.values.reduce(0) { $0 + $1.download }
        if self.cumulativeUpload < bucketUploadTotal {
            self.cumulativeUpload = bucketUploadTotal
            changed = true
        }
        if self.cumulativeDownload < bucketDownloadTotal {
            self.cumulativeDownload = bucketDownloadTotal
            changed = true
        }

        return changed
    }

    private func makeSnapshot(
        window: InsightsTimeWindow,
        buckets: [TrafficInsightsMinuteBucket])
        -> TrafficInsightsSnapshot
    {
        var entries: [TrafficInsightFacetEntry] = []

        for bucket in buckets {
            entries.append(contentsOf: bucket.entries.values)
        }

        return self.makeSnapshot(
            window: window,
            totalUpload: buckets.reduce(0) { $0 + $1.upload },
            totalDownload: buckets.reduce(0) { $0 + $1.download },
            entries: entries,
            trendPoints: self.makeTrendPoints(from: buckets))
    }

    private func makeSnapshot(
        window: InsightsTimeWindow,
        totalUpload: Int64,
        totalDownload: Int64,
        entries: [TrafficInsightFacetEntry],
        trendPoints: [TrafficInsightsTrendPoint])
        -> TrafficInsightsSnapshot
    {
        return TrafficInsightsSnapshot(
            window: window,
            totalUpload: totalUpload,
            totalDownload: totalDownload,
            domainItems: self.makeDomainItems(from: entries),
            ruleItems: self.makeRuleItems(from: entries),
            routeItems: self.makeRouteItems(from: entries),
            trendPoints: trendPoints)
    }

    private func makeTrendPoints(from buckets: [TrafficInsightsMinuteBucket]) -> [TrafficInsightsTrendPoint] {
        buckets.map {
            TrafficInsightsTrendPoint(
                minuteStart: $0.minuteStart,
                upload: $0.upload,
                download: $0.download)
        }
    }

    private func makeRuntimeTrendPoints(now: Date) -> [TrafficInsightsTrendPoint] {
        let nowTimestamp = Int64(now.timeIntervalSince1970)
        let minuteCutoff = nowTimestamp - Int64(self.maxPersistedMinutes * 60)
        let hourCutoff = nowTimestamp - Int64(self.maxPersistedHours * 3600)

        let dayPoints = self.dailyTrendBuckets.values
            .filter { $0.bucketStart < hourCutoff }
            .sorted { $0.bucketStart < $1.bucketStart }
            .map {
                TrafficInsightsTrendPoint(
                    minuteStart: $0.bucketStart,
                    upload: $0.upload,
                    download: $0.download)
            }
        let hourPoints = self.hourlyTrendBuckets.values
            .filter { $0.bucketStart >= hourCutoff && $0.bucketStart < minuteCutoff }
            .sorted { $0.bucketStart < $1.bucketStart }
            .map {
                TrafficInsightsTrendPoint(
                    minuteStart: $0.bucketStart,
                    upload: $0.upload,
                    download: $0.download)
            }
        let minutePoints = self.persistedBuckets.values
            .filter { $0.minuteStart >= minuteCutoff }
            .sorted { $0.minuteStart < $1.minuteStart }
            .map {
                TrafficInsightsTrendPoint(
                    minuteStart: $0.minuteStart,
                    upload: $0.upload,
                    download: $0.download)
            }

        return self.downsampleTrendPoints(dayPoints + hourPoints + minutePoints, maxPoints: self.maxRuntimeTrendPoints)
    }

    private func downsampleTrendPoints(
        _ points: [TrafficInsightsTrendPoint],
        maxPoints: Int)
        -> [TrafficInsightsTrendPoint]
    {
        guard points.count > maxPoints, maxPoints > 0 else { return points }

        let chunkSize = Int(ceil(Double(points.count) / Double(maxPoints)))
        var result: [TrafficInsightsTrendPoint] = []
        result.reserveCapacity(maxPoints)

        var index = 0
        while index < points.count {
            let chunkEnd = min(index + chunkSize, points.count)
            let chunk = points[index..<chunkEnd]
            guard let first = chunk.first else { break }

            result.append(TrafficInsightsTrendPoint(
                minuteStart: first.minuteStart,
                upload: chunk.reduce(Int64(0)) { $0 + $1.upload },
                download: chunk.reduce(Int64(0)) { $0 + $1.download }))
            index = chunkEnd
        }

        return result
    }

    private func makeDomainItems(from entries: [TrafficInsightFacetEntry]) -> [TrafficInsightsDomainItem] {
        struct Accumulator {
            var upload: Int64 = 0
            var download: Int64 = 0
            var lastSeenAt: TimeInterval = 0
            var rules: [String: Int64] = [:]
            var routes: [String: Int64] = [:]
        }

        var accumulators: [String: Accumulator] = [:]
        for entry in entries {
            var accumulator = accumulators[entry.domain] ?? Accumulator()
            accumulator.upload += entry.upload
            accumulator.download += entry.download
            accumulator.lastSeenAt = max(accumulator.lastSeenAt, entry.lastSeenAt)
            accumulator.rules[entry.rule, default: 0] += entry.total
            accumulator.routes[entry.route, default: 0] += entry.total
            accumulators[entry.domain] = accumulator
        }

        return accumulators.map { domain, accumulator in
            TrafficInsightsDomainItem(
                domain: domain,
                upload: accumulator.upload,
                download: accumulator.download,
                uniqueRuleCount: accumulator.rules.count,
                uniqueRouteCount: accumulator.routes.count,
                topRule: self.topFacetName(from: accumulator.rules),
                topRoute: self.topFacetName(from: accumulator.routes),
                lastSeenAt: accumulator.lastSeenAt)
        }
    }

    private func makeRuleItems(from entries: [TrafficInsightFacetEntry]) -> [TrafficInsightsRuleItem] {
        struct Accumulator {
            var upload: Int64 = 0
            var download: Int64 = 0
            var lastSeenAt: TimeInterval = 0
            var domains: [String: Int64] = [:]
            var routes: [String: Int64] = [:]
        }

        var accumulators: [String: Accumulator] = [:]
        for entry in entries {
            var accumulator = accumulators[entry.rule] ?? Accumulator()
            accumulator.upload += entry.upload
            accumulator.download += entry.download
            accumulator.lastSeenAt = max(accumulator.lastSeenAt, entry.lastSeenAt)
            accumulator.domains[entry.domain, default: 0] += entry.total
            accumulator.routes[entry.route, default: 0] += entry.total
            accumulators[entry.rule] = accumulator
        }

        return accumulators.map { rule, accumulator in
            TrafficInsightsRuleItem(
                rule: rule,
                upload: accumulator.upload,
                download: accumulator.download,
                uniqueDomainCount: accumulator.domains.count,
                uniqueRouteCount: accumulator.routes.count,
                topDomain: self.topFacetName(from: accumulator.domains),
                topRoute: self.topFacetName(from: accumulator.routes),
                lastSeenAt: accumulator.lastSeenAt)
        }
    }

    private func makeRouteItems(from entries: [TrafficInsightFacetEntry]) -> [TrafficInsightsRouteItem] {
        struct Accumulator {
            var upload: Int64 = 0
            var download: Int64 = 0
            var lastSeenAt: TimeInterval = 0
            var domains: [String: Int64] = [:]
            var rules: [String: Int64] = [:]
        }

        var accumulators: [String: Accumulator] = [:]
        for entry in entries {
            var accumulator = accumulators[entry.route] ?? Accumulator()
            accumulator.upload += entry.upload
            accumulator.download += entry.download
            accumulator.lastSeenAt = max(accumulator.lastSeenAt, entry.lastSeenAt)
            accumulator.domains[entry.domain, default: 0] += entry.total
            accumulator.rules[entry.rule, default: 0] += entry.total
            accumulators[entry.route] = accumulator
        }

        return accumulators.map { route, accumulator in
            TrafficInsightsRouteItem(
                route: route,
                upload: accumulator.upload,
                download: accumulator.download,
                uniqueDomainCount: accumulator.domains.count,
                uniqueRuleCount: accumulator.rules.count,
                topDomain: self.topFacetName(from: accumulator.domains),
                topRule: self.topFacetName(from: accumulator.rules),
                lastSeenAt: accumulator.lastSeenAt)
        }
    }

    private func topFacetName(from values: [String: Int64]) -> String {
        values.max { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value < rhs.value
            }
            return lhs.key.localizedStandardCompare(rhs.key) == .orderedDescending
        }?.key ?? "Unknown"
    }

    private func entryID(domain: String, rule: String, route: String) -> String {
        "\(domain)\u{1F}\(rule)\u{1F}\(route)"
    }
}
