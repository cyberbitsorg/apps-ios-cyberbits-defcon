import Foundation
import SwiftData
import BackgroundTasks
import os

@ModelActor
actor FetchCoordinator {

    static let backgroundTaskID = "com.cyberbits.defcon.refresh"
    private static let log = Logger(subsystem: "com.cyberbits.defcon", category: "fetch")

    /// Runs the full pipeline. Returns the newly computed DefconStatus (or nil on total failure).
    func runFetchCycle() async -> DefconStatus? {
        let t0 = Date()
        let previousStatus = try? DefconStore.currentStatus(context: modelContext)
        let previousLevel = previousStatus?.level ?? 5  // 5 = lowest threat baseline

        // 1. Load dedup state. GUIDs from the article store are the cheap, exact
        //    "have I already stored this?" check; the dedup log (kept at 300) catches
        //    near-duplicates across feeds whose GUIDs differ but titles overlap.
        let existingGuids = ArticleStore.existingGuids(context: modelContext)
        let fingerprints = DedupStore.fingerprints(context: modelContext)
        let recentTitles = DedupStore.recentTitles(context: modelContext)
        let recentCves = CVEStore.recentCVEs(context: modelContext)
        print("[DEFCON] fetch start: storedGuids=\(existingGuids.count) dedupFps=\(fingerprints.count) dedupTitles=\(recentTitles.count) recentCves=\(recentCves.count)")

        // 2. Fetch all feeds concurrently
        var allRaw: [RawArticle] = []
        var perSource: [String: Int] = [:]
        await withTaskGroup(of: (FeedSource, [RawArticle]).self) { group in
            for source in FeedSource.allCases {
                group.addTask { (source, await Self.fetch(source: source)) }
            }
            for await (source, batch) in group {
                perSource[source.rawValue] = batch.count
                allRaw.append(contentsOf: batch)
            }
        }
        print("[DEFCON] feeds raw=\(allRaw.count) perSource=\(perSource)")

        // 3. Deduplicate. Cheap GUID match first (skips the TF-IDF cosine pass for
        //    anything already in the store), then fingerprint + near-dupe checks
        //    against the dedup log and within this batch.
        // Pre-tokenize the dedup-log titles once; Jaccard re-uses the same corpus
        // for every candidate, so tokenizing per-query was ~22K NLTokenizer calls.
        var corpusTitles = recentTitles
        var corpusTokens = recentTitles.map { Deduplicator.tokenSet($0) }
        var seenCves = recentCves
        var acceptedFingerprints = Set<String>()
        var unique: [RawArticle] = []
        var acceptedCvesPerArticle: [Set<String>] = []
        var droppedGuid = 0, droppedBatchFp = 0, droppedExistingFp = 0, droppedNearDupe = 0
        for raw in allRaw {
            if existingGuids.contains(raw.guid) { droppedGuid += 1; continue }
            let fp = Deduplicator.fingerprint(raw.title)
            if acceptedFingerprints.contains(fp) { droppedBatchFp += 1; continue }
            if fingerprints.contains(fp) { droppedExistingFp += 1; continue }
            let dedup = Deduplicator(
                existingFingerprints: [],
                recentTitles: corpusTitles,
                recentTokens: corpusTokens,
                recentCves: seenCves
            )
            if dedup.isDuplicate(raw) { droppedNearDupe += 1; continue }
            acceptedFingerprints.insert(fp)
            corpusTitles.append(raw.title)
            corpusTokens.append(Deduplicator.tokenSet(raw.title))
            let cves = Deduplicator.extractCVEs("\(raw.title) \(raw.summary)")
            seenCves.formUnion(cves)
            acceptedCvesPerArticle.append(cves)
            unique.append(raw)
        }
        let newCount = unique.count
        print("[DEFCON] dedup: new=\(newCount) droppedGuid=\(droppedGuid) droppedBatchFp=\(droppedBatchFp) droppedExistingFp=\(droppedExistingFp) droppedNearDupe=\(droppedNearDupe) dt=\(Int(Date().timeIntervalSince(t0)*1000))ms")

        // 4. Score (v2 per-article: Track A trigger + Track B sub-scores) and store
        for (idx, raw) in unique.enumerated() {
            let result = Scorer.computeArticleScore(title: raw.title, summary: raw.summary)
            ArticleStore.upsert(raw, score: result.score, trigger: result.trigger, context: modelContext)
            DedupStore.record(fingerprint: Deduplicator.fingerprint(raw.title),
                              title: raw.title, context: modelContext)
            for cve in acceptedCvesPerArticle[idx] {
                CVEStore.record(cve, context: modelContext)
            }
        }
        do {
            try modelContext.save()
        } catch {
            print("[DEFCON] save after insert FAILED: \(error.localizedDescription)")
        }

        // 5. Trim (articles to 100/20, dedup log to 300, CVE log by TTL, volume window 168)
        ArticleStore.trim(context: modelContext)
        DedupStore.trim(context: modelContext)
        CVEStore.trim(context: modelContext)
        VolumeStore.record(newCount, context: modelContext)
        VolumeStore.trim(context: modelContext)
        do {
            try modelContext.save()
        } catch {
            print("[DEFCON] save after trim FAILED: \(error.localizedDescription)")
        }
        let articlesAfter = (try? modelContext.fetch(FetchDescriptor<Article>()).count) ?? -1
        let dedupAfter = (try? modelContext.fetch(FetchDescriptor<DedupRecord>()).count) ?? -1
        print("[DEFCON] after save+trim: articles=\(articlesAfter) dedup=\(dedupAfter) total=\(Int(Date().timeIntervalSince(t0)*1000))ms")

        // 6. Compute global DEFCON (v2): weighted-max over the 20 most recent articles.
        //    Matches docker's `get_recent_articles(pool, limit=20)` scope so the
        //    gauge reflects active threats rather than the full backfill.
        let windowArticles = ArticleStore.fetchRecent(limit: 20, context: modelContext)
        let window: [Scorer.WindowArticle] = windowArticles.map { article in
            Scorer.WindowArticle(
                title: article.title,
                score: article.defconScore,
                trigger: article.trigger,
                publishedAt: article.publishedAt
            )
        }
        // Volume baseline is the mean of the last 168 refresh counts (nil until coldStartMin).
        let baseline = VolumeStore.baseline(context: modelContext)
        let global = Scorer.computeGlobalScore(window: window, newCount: newCount, baseline: baseline)

        // 7. Apply sticky-level state machine, then write history.
        let rawLevel = Scorer.levelFromScore(global.score)
        let stickyState = StickyLevel.read(context: modelContext)
        let evidenceAnchor = Self.evidenceAnchor(for: stickyState.floor, in: windowArticles)
        let sticky = StickyLevel.computeDisplayedLevel(
            rawLevel: rawLevel,
            state: stickyState,
            evidenceAnchor: evidenceAnchor
        )
        StickyLevel.write(sticky, context: modelContext)
        DefconStore.writeHistory(global, displayedLevel: sticky.displayedLevel, context: modelContext)
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

    /// Re-applies the sticky-level state machine against the current article
    /// window without doing any network fetch. Cheap to call on app open so
    /// the displayed DEFCON level decays in real time even when background
    /// refreshes were skipped (e.g. simulator, or iOS throttling on device).
    func tickStickyLevel() async -> DefconStatus? {
        let windowArticles = ArticleStore.fetchRecent(limit: 20, context: modelContext)
        guard !windowArticles.isEmpty else { return nil }
        let window: [Scorer.WindowArticle] = windowArticles.map { article in
            Scorer.WindowArticle(
                title: article.title,
                score: article.defconScore,
                trigger: article.trigger,
                publishedAt: article.publishedAt
            )
        }
        let baseline = VolumeStore.baseline(context: modelContext)
        let global = Scorer.computeGlobalScore(window: window, newCount: 0, baseline: baseline)
        let rawLevel = Scorer.levelFromScore(global.score)
        let stickyState = StickyLevel.read(context: modelContext)
        let evidenceAnchor = Self.evidenceAnchor(for: stickyState.floor, in: windowArticles)
        let sticky = StickyLevel.computeDisplayedLevel(
            rawLevel: rawLevel,
            state: stickyState,
            evidenceAnchor: evidenceAnchor
        )
        print("[DEFCON] tick: raw=\(rawLevel) floor=\(stickyState.floor ?? -1) until=\(stickyState.untilAt?.description ?? "nil") evidence=\(evidenceAnchor?.description ?? "nil") → displayed=\(sticky.displayedLevel) newFloor=\(sticky.newFloor) newUntil=\(sticky.newUntilAt?.description ?? "nil")")
        StickyLevel.write(sticky, context: modelContext)
        DefconStore.writeHistory(global, displayedLevel: sticky.displayedLevel, context: modelContext)
        try? modelContext.save()
        return try? DefconStore.currentStatus(context: modelContext)
    }

    /// Most recent published date of an article in the window whose own score
    /// maps to `floor` or more severe — i.e. an article that, on its own, would
    /// support holding the floor. `nil` if no such article exists (floor has no
    /// supporting evidence in the current window).
    private static func evidenceAnchor(for floor: Int?, in articles: [Article]) -> Date? {
        guard let floor else { return nil }
        return articles
            .filter { Scorer.levelFromScore($0.defconScore) <= floor }
            .map { $0.publishedAt }
            .max()
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
