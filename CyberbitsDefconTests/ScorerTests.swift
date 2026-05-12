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
        let g = Scorer.computeGlobalScore(window: [old, recent], newCount: 0, baseline: nil)
        // The recent 80-score article has weight ≈ 1; the 23h-old article has weight ≈ 1/24.
        XCTAssertEqual(g.triggerArticleTitle, "fresh")
        XCTAssertEqual(g.weightedMax, 80, accuracy: 1.0)
    }

    func test_globalScore_volumeBonusCapped() {
        // 100x volume vs baseline → bonus capped at 10
        let g = Scorer.computeGlobalScore(window: [], newCount: 100, baseline: 1.0)
        XCTAssertEqual(g.volumeBonus, 10, accuracy: 0.01)
    }
}
