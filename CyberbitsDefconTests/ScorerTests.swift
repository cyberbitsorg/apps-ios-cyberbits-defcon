import XCTest
@testable import CyberbitsDefcon

final class ScorerTests: XCTestCase {

    func test_levelFromScore_inverted() {
        XCTAssertEqual(Scorer.levelFromScore(95), 1) // CRITICAL
        XCTAssertEqual(Scorer.levelFromScore(70), 2) // HIGH
        XCTAssertEqual(Scorer.levelFromScore(45), 3) // ELEVATED
        XCTAssertEqual(Scorer.levelFromScore(25), 4) // GUARDED
        XCTAssertEqual(Scorer.levelFromScore(5),  5) // LOW
    }

    // MARK: - Per-article (v2)

    func test_articleScore_emptyReturnsZero() {
        let r = Scorer.computeArticleScore(title: "", summary: "")
        XCTAssertEqual(r.score, 0)
        XCTAssertNil(r.trigger)
    }

    func test_articleScore_activeExploitationTriggersTrackA() {
        let r = Scorer.computeArticleScore(
            title: "Critical RCE actively exploited in the wild",
            summary: "Attackers are weaponizing the flaw against government targets."
        )
        XCTAssertEqual(r.trigger, .activeExploitation)
        // Track A base = 80 + capped bonus; final score must be ≥ base
        XCTAssertGreaterThanOrEqual(r.score, 80)
        XCTAssertLessThanOrEqual(r.score, 100)
    }

    func test_articleScore_maxSeverityPhraseScores9() {
        // "max severity" / "maximum severity" → infers CVSS 9.0 → cveScore 27
        let r = Scorer.computeArticleScore(
            title: "Ubiquiti patches three max severity unifi os vulnerabilities",
            summary: ""
        )
        XCTAssertEqual(r.cve, 27.0, accuracy: 0.1)
    }

    func test_articleScore_explicitCVSSReadsBest() {
        let r = Scorer.computeArticleScore(
            title: "OpenSSL vulnerability",
            summary: "Researchers disclosed CVSS 9.8 issue in the library"
        )
        // CVE dimension scaled to 0-30; 9.8/10 * 30 = 29.4 → contributes heavily to Track B
        XCTAssertGreaterThan(r.cve, 25)
    }

    func test_articleScore_newsletterSuppressesTrigger() {
        // The title gates trigger detection — a "newsletter" headline should not fire.
        let r = Scorer.computeArticleScore(
            title: "Weekly newsletter: critical RCE actively exploited",
            summary: "Roundup of this week's news"
        )
        XCTAssertNil(r.trigger)
    }

    func test_articleScore_trackBCappedAt80() {
        // Pile on many TIER1 keywords; Track B must still cap at 80
        let r = Scorer.computeArticleScore(
            title: "zero-day nation-state ransomware attack critical infrastructure",
            summary: "supply chain attack stealer campaign infostealer credential stealer malware campaign"
        )
        XCTAssertLessThanOrEqual(r.trackB, 80)
    }

    // MARK: - Global (v2)

    func test_globalScore_emptyWindowIsZero() {
        let g = Scorer.computeGlobalScore(window: [], newCount: 0, baseline: nil)
        XCTAssertEqual(g.score, 0)
    }

    func test_globalScore_weightsRecentArticlesHigher() {
        let now = Date()
        let recent = Scorer.WindowArticle(title: "fresh", score: 80,
                                          trigger: .activeExploitation,
                                          publishedAt: now)
        let old = Scorer.WindowArticle(title: "old", score: 90,
                                       trigger: .activeExploitation,
                                       publishedAt: now.addingTimeInterval(-23 * 3600))
        // Pin to the legacy 24h window so the math stays deterministic.
        let g = Scorer.computeGlobalScore(window: [old, recent], newCount: 0,
                                          baseline: nil, now: now, windowHours: 24)
        // The recent 80-score article has weight ≈ 1; the 23h-old article has weight ≈ 1/24.
        XCTAssertEqual(g.triggerArticleTitle, "fresh")
        XCTAssertEqual(g.weightedMax, 80, accuracy: 1.0)
    }

    func test_globalScore_volumeBonusCapped() {
        // 100x volume vs baseline → bonus capped at 10
        let g = Scorer.computeGlobalScore(window: [], newCount: 100, baseline: 1.0)
        XCTAssertEqual(g.volumeBonus, 10, accuracy: 0.01)
    }

    // MARK: - Distribution-aware aggregation (one lone article must not max the gauge)

    func test_globalScore_loneHighNonToptierPulledDownByDistribution() {
        let now = Date()
        let window = [
            Scorer.WindowArticle(title: "lone", score: 65, trigger: .malwareCampaign, publishedAt: now),
            Scorer.WindowArticle(title: "second", score: 45, trigger: nil, publishedAt: now),
            Scorer.WindowArticle(title: "low1", score: 10, trigger: nil, publishedAt: now),
            Scorer.WindowArticle(title: "low2", score: 5, trigger: nil, publishedAt: now),
        ]
        let g = Scorer.computeGlobalScore(window: window, newCount: 0, baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(g.weightedMax, 0.6 * 65 + 0.4 * 45, accuracy: 0.1) // 57, not 65
        XCTAssertLessThan(g.weightedMax, 65)
        XCTAssertEqual(g.triggerArticleTitle, "lone")
    }

    func test_globalScore_toptierSingleEventStillSpikes() {
        let now = Date()
        let window = [
            Scorer.WindowArticle(title: "crit", score: 80, trigger: .activeExploitation, publishedAt: now),
            Scorer.WindowArticle(title: "low1", score: 20, trigger: nil, publishedAt: now),
            Scorer.WindowArticle(title: "low2", score: 15, trigger: nil, publishedAt: now),
        ]
        let g = Scorer.computeGlobalScore(window: window, newCount: 0, baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(g.weightedMax, 80, accuracy: 0.1)
        XCTAssertEqual(g.trigger, .activeExploitation)
        XCTAssertEqual(g.triggerArticleTitle, "crit")
    }

    func test_globalScore_malwareCampaignDoesNotGetSpikeCarveout() {
        let now = Date()
        let window = [
            Scorer.WindowArticle(title: "lone", score: 65, trigger: .malwareCampaign, publishedAt: now),
            Scorer.WindowArticle(title: "second", score: 30, trigger: nil, publishedAt: now),
        ]
        let g = Scorer.computeGlobalScore(window: window, newCount: 0, baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(g.weightedMax, 0.6 * 65 + 0.4 * 30, accuracy: 0.1) // 51, not 65
    }

    func test_globalScore_twoHighArticlesReachLevel2() {
        let now = Date()
        let window = [
            Scorer.WindowArticle(title: "a", score: 65, trigger: .malwareCampaign, publishedAt: now),
            Scorer.WindowArticle(title: "b", score: 62, trigger: .malwareCampaign, publishedAt: now),
        ]
        let g = Scorer.computeGlobalScore(window: window, newCount: 0, baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(g.weightedMax, 0.6 * 65 + 0.4 * 62, accuracy: 0.1) // 63.8
        XCTAssertEqual(Scorer.levelFromScore(g.score), 2)
    }

    // MARK: - Volume bonus baseline floor (sparse per-cycle counts must not saturate)

    func test_globalScore_volumeBonusLowBaselineSingleArticleNoBonus() {
        let now = Date()
        let window = [Scorer.WindowArticle(title: "a", score: 50, trigger: nil, publishedAt: now)]
        let g = Scorer.computeGlobalScore(window: window, newCount: 1, baseline: 0.16, now: now, windowHours: 48)
        XCTAssertEqual(g.volumeBonus, 0, accuracy: 0.001)
    }

    func test_globalScore_volumeBonusFloorRequiresRealSurge() {
        let now = Date()
        let window = [Scorer.WindowArticle(title: "a", score: 50, trigger: nil, publishedAt: now)]
        let g = Scorer.computeGlobalScore(window: window, newCount: 3, baseline: 0.5, now: now, windowHours: 48)
        XCTAssertEqual(g.volumeBonus, 0, accuracy: 0.001)
    }

    // MARK: - Weekend-aware decay window

    /// Build a UTC date for explicit Y/M/D.
    private func utcDate(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func test_currentWindowHours_weekendUses72h() {
        // 2026-05-23 is a Saturday (UTC).
        let saturday = utcDate(2026, 5, 23)
        XCTAssertEqual(Scorer.currentWindowHours(now: saturday), 72)
        // 2026-05-24 is a Sunday (UTC).
        let sunday = utcDate(2026, 5, 24)
        XCTAssertEqual(Scorer.currentWindowHours(now: sunday), 72)
    }

    func test_currentWindowHours_weekdayUses48h() {
        // 2026-05-25 is a Monday (UTC).
        let monday = utcDate(2026, 5, 25)
        XCTAssertEqual(Scorer.currentWindowHours(now: monday), 48)
        // 2026-05-29 is a Friday (UTC).
        let friday = utcDate(2026, 5, 29)
        XCTAssertEqual(Scorer.currentWindowHours(now: friday), 48)
    }

    func test_globalScore_windowHoursParameterControlsDecay() {
        let now = Date()
        let aged = Scorer.WindowArticle(title: "aged", score: 90,
                                        trigger: .activeExploitation,
                                        publishedAt: now.addingTimeInterval(-50 * 3600))
        // 50h-old article with a 48h window → fully decayed.
        let short = Scorer.computeGlobalScore(window: [aged], newCount: 0,
                                              baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(short.weightedMax, 0, accuracy: 0.01)

        // Same article with a 72h window → 90 * (72-50)/72 ≈ 27.5.
        let long = Scorer.computeGlobalScore(window: [aged], newCount: 0,
                                             baseline: nil, now: now, windowHours: 72)
        XCTAssertEqual(long.weightedMax, 90 * (72.0 - 50.0) / 72.0, accuracy: 0.5)
    }

    func test_globalScore_propagatesTriggerArticlePublishedAt() {
        let now = Date()
        let published = now.addingTimeInterval(-3 * 3600)
        let art = Scorer.WindowArticle(title: "winner", score: 70,
                                       trigger: .activeExploitation,
                                       publishedAt: published)
        let g = Scorer.computeGlobalScore(window: [art], newCount: 0,
                                          baseline: nil, now: now, windowHours: 48)
        XCTAssertEqual(g.triggerArticleTitle, "winner")
        XCTAssertEqual(g.triggerArticlePublishedAt, published)

        let empty = Scorer.computeGlobalScore(window: [], newCount: 0, baseline: nil)
        XCTAssertNil(empty.triggerArticlePublishedAt)
    }
}
