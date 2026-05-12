import Foundation
import SwiftData
import BackgroundTasks

@ModelActor
actor FetchCoordinator {

    static let backgroundTaskID = "com.cyberbits.defcon.refresh"

    /// Runs the full pipeline. Returns the newly computed DefconStatus (or nil on total failure).
    func runFetchCycle() async -> DefconStatus? {
        let previousStatus = try? DefconStore.currentStatus(context: modelContext)
        let previousLevel = previousStatus?.level ?? 5  // 5 = lowest threat baseline

        // 1. Load dedup state from the dedup log (kept at 300, independent of
        //    the 100-article display cap). Mirrors docker's redis recent_titles.
        let fingerprints = DedupStore.fingerprints(context: modelContext)
        let recentTitles = DedupStore.recentTitles(context: modelContext)

        // 2. Fetch all feeds concurrently
        var allRaw: [RawArticle] = []
        await withTaskGroup(of: [RawArticle].self) { group in
            for source in FeedSource.allCases {
                group.addTask { await Self.fetch(source: source) }
            }
            for await batch in group { allRaw.append(contentsOf: batch) }
        }

        // 3. Deduplicate (against store + within batch)
        var acceptedFingerprints = Set<String>()
        var acceptedTitles: [String] = []
        var unique: [RawArticle] = []
        for raw in allRaw {
            let fp = Deduplicator.fingerprint(raw.title)
            if acceptedFingerprints.contains(fp) { continue }
            let dedup = Deduplicator(
                existingFingerprints: fingerprints.union(acceptedFingerprints),
                recentTitles: recentTitles + acceptedTitles
            )
            if dedup.isDuplicate(raw) { continue }
            acceptedFingerprints.insert(fp)
            acceptedTitles.append(raw.title)
            unique.append(raw)
        }
        let newCount = unique.count

        // 4. Score (v2 per-article: Track A trigger + Track B sub-scores) and store
        for raw in unique {
            let result = Scorer.computeArticleScore(title: raw.title, summary: raw.summary)
            ArticleStore.upsert(raw, score: result.score, trigger: result.trigger, context: modelContext)
            DedupStore.record(fingerprint: Deduplicator.fingerprint(raw.title),
                              title: raw.title, context: modelContext)
        }
        try? modelContext.save()

        // 5. Trim (articles to 100/15, dedup log to 300)
        ArticleStore.trim(context: modelContext)
        DedupStore.trim(context: modelContext)
        try? modelContext.save()

        // 6. Compute global DEFCON (v2): weighted-max over 24h window + volume bonus
        let windowArticles = ArticleStore.articlesInWindow(hours: 24, context: modelContext)
        let window: [Scorer.WindowArticle] = windowArticles.map { article in
            Scorer.WindowArticle(
                title: article.title,
                score: article.defconScore,
                trigger: article.trigger,
                publishedAt: article.publishedAt
            )
        }
        // Without a volume baseline established yet, pass nil — bonus becomes 0.
        let global = Scorer.computeGlobalScore(window: window, newCount: newCount, baseline: nil)

        // 7. Write history
        DefconStore.writeHistory(global, context: modelContext)
        try? modelContext.save()

        // 8. Update last refresh timestamp
        AppSettings.lastRefreshedAt = Date()

        // 9. Notify
        //   In the inverted DEFCON scale, a LOWER level number means a HIGHER threat.
        let newStatus = try? DefconStore.currentStatus(context: modelContext)
        if let status = newStatus, status.level < previousLevel {
            await MainActor.run {
                NotificationScheduler.notifyDefconLevelChange(newLevel: status.level, label: status.label)
            }
        }
        if newCount > 0 {
            await MainActor.run {
                NotificationScheduler.notifyNewArticles(count: newCount)
            }
        }

        return newStatus
    }

    private static func fetch(source: FeedSource) async -> [RawArticle] {
        do {
            let (data, _) = try await URLSession.shared.data(from: source.feedURL)
            if source.isJSONAPI {
                return (try? await FeedParser.parseSecurityAffairs(jsonData: data)) ?? []
            } else {
                return (try? await FeedParser.parse(xmlData: data, source: source)) ?? []
            }
        } catch {
            return []
        }
    }

    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(AppSettings.refreshIntervalMinutes * 60))
        try? BGTaskScheduler.shared.submit(request)
    }
}
