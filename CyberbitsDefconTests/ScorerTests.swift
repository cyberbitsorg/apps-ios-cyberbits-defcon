import XCTest
@testable import CyberbitsDefcon

final class ScorerTests: XCTestCase {

    func test_volume_scoresProportionally() {
        let factors = Scorer.computeGlobalScore(texts: Array(repeating: "test", count: 6), newCount: 6)
        XCTAssertEqual(factors.volumeScore, 12.5, accuracy: 0.01)
    }

    func test_volume_capsAt25() {
        let factors = Scorer.computeGlobalScore(texts: ["test"], newCount: 100)
        XCTAssertEqual(factors.volumeScore, 25.0, accuracy: 0.01)
    }

    func test_cve_extractsExplicitCVSS() {
        let factors = Scorer.computeGlobalScore(texts: ["CVSS 9.8 critical vulnerability found"], newCount: 0)
        XCTAssertEqual(factors.cveScore, (9.8 / 10.0) * 25, accuracy: 0.5)
    }

    func test_cve_infersSeverityWord() {
        let factors = Scorer.computeGlobalScore(texts: ["Critical vulnerability in OpenSSL"], newCount: 0)
        XCTAssertEqual(factors.cveScore, (9.0 / 10.0) * 25, accuracy: 0.01)
    }

    func test_keywords_tier1ScoresFive() {
        let factors = Scorer.computeGlobalScore(texts: ["zero-day exploit in the wild"], newCount: 0)
        XCTAssertGreaterThan(factors.keywordScore, 0)
    }

    func test_level_belowTwentyIsOne() {
        let f = DefconFactors(volumeScore: 0, cveScore: 0, impactScore: 0, keywordScore: 0)
        XCTAssertEqual(f.level, 1)
    }

    func test_level_eightyOrAboveIsFive() {
        let f = DefconFactors(volumeScore: 25, cveScore: 25, impactScore: 25, keywordScore: 5)
        XCTAssertEqual(f.level, 5)
    }

    func test_articleScore_returnsDoubleInRange() {
        let score = Scorer.computeArticleScore(title: "Ransomware hits hospital", summary: "Critical attack")
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }
}
