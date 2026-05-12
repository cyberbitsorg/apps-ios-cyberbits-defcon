import Foundation
import SwiftData
import BackgroundTasks

@ModelActor
actor FetchCoordinator {

    static let backgroundTaskID = "com.cyberbits.defcon.refresh"

    /// Runs the full pipeline. Returns the newly computed DefconStatus (or nil on total failure).
    func runFetchCycle() async -> DefconStatus? {
        let previousStatus = try? DefconStore.currentStatus(context: modelContext)
        let previousLevel = previousStatus?.level ?? 0

        // 1. Load dedup state from persisted store
        let fingerprints = ArticleStore.existingFingerprints(context: modelContext)
        let recentTitles = ArticleStore.recentTitles(context: modelContext)
        let deduplicator = Deduplicator(existingFingerprints: fingerprints, recentTitles: recentTitles)

        // 2. Fetch all feeds concurrently
        var allRaw: [RawArticle] = []
        await withTaskGroup(of: [RawArticle].self) { group in
            for source in FeedSource.allCases {
                group.addTask { await Self.fetch(source: source) }
            }
            for await batch in group { allRaw.append(contentsOf: batch) }
        }

        // 3. Deduplicate
        let unique = allRaw.filter { !deduplicator.isDuplicate($0) }
        let newCount = unique.count

        // 4. Score and store
        for raw in unique {
            let score = Scorer.computeArticleScore(title: raw.title, summary: raw.summary)
            ArticleStore.upsert(raw, score: score, context: modelContext)
        }
        try? modelContext.save()

        // 5. Trim
        ArticleStore.trim(context: modelContext)
        try? modelContext.save()

        // 6. Compute global DEFCON
        let recent = ArticleStore.fetchRecent(limit: 20, context: modelContext)
        let texts = recent.map { "\($0.title) \($0.summary)".lowercased() }
        let factors = Scorer.computeGlobalScore(texts: texts, newCount: newCount)

        // 7. Write history
        DefconStore.writeHistory(factors: factors, context: modelContext)
        try? modelContext.save()

        // 8. Update last refresh timestamp
        AppSettings.lastRefreshedAt = Date()

        // 9. Notify
        let newStatus = try? DefconStore.currentStatus(context: modelContext)
        if let status = newStatus, status.level > previousLevel {
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
