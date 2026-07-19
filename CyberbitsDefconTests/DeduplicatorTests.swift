import XCTest
@testable import CyberbitsDefcon

final class DeduplicatorTests: XCTestCase {

    func test_fingerprint_isIdenticalForSameTitle() {
        let a = Deduplicator.fingerprint("Zero-day exploit found in OpenSSL")
        let b = Deduplicator.fingerprint("Zero-day exploit found in OpenSSL")
        XCTAssertEqual(a, b)
    }

    func test_fingerprint_isCaseInsensitive() {
        let a = Deduplicator.fingerprint("RANSOMWARE Attack Hits Hospital")
        let b = Deduplicator.fingerprint("ransomware attack hits hospital")
        XCTAssertEqual(a, b)
    }

    func test_fingerprint_ignoresPunctuation() {
        let a = Deduplicator.fingerprint("Zero-day exploit, found in OpenSSL!")
        let b = Deduplicator.fingerprint("Zero day exploit found in OpenSSL")
        XCTAssertEqual(a, b)
    }

    func test_l1_detectsDuplicateByFingerprint() {
        let dedup = Deduplicator(
            existingFingerprints: [Deduplicator.fingerprint("Zero-day in OpenSSL")],
            recentTitles: []
        )
        let article = makeArticle(title: "Zero-day in OpenSSL")
        XCTAssertTrue(dedup.isDuplicate(article))
    }

    func test_l1_passesUniqueFingerprintThrough() {
        let dedup = Deduplicator(existingFingerprints: [], recentTitles: [])
        let article = makeArticle(title: "Brand new unique story about security")
        XCTAssertFalse(dedup.isDuplicate(article))
    }

    func test_l2_jaccard_detectsHighOverlap() {
        let dedup = Deduplicator(
            existingFingerprints: [],
            recentTitles: ["Critical vulnerability found in OpenSSL library allows RCE"]
        )
        let article = makeArticle(title: "Critical OpenSSL vulnerability allows remote code execution")
        XCTAssertTrue(dedup.isDuplicate(article))
    }

    func test_l2_jaccard_passesLowOverlap() {
        let dedup = Deduplicator(
            existingFingerprints: [],
            recentTitles: ["Apple releases iOS update with security patches"]
        )
        let article = makeArticle(title: "Russian hackers target NATO infrastructure")
        XCTAssertFalse(dedup.isDuplicate(article))
    }

    func test_temporalConflict_differentMonthsAreNotDuplicates() {
        let dedup = Deduplicator(
            existingFingerprints: [],
            recentTitles: ["January Patch Tuesday fixes critical vulnerabilities"]
        )
        let article = makeArticle(title: "February Patch Tuesday fixes critical vulnerabilities")
        XCTAssertFalse(dedup.isDuplicate(article))
    }

    func test_sharedVendorProduct_oraclePeopleSoftDedupes() {
        // ShinyHunters/Oracle PeopleSoft 0-day story, different headlines: share the
        // "oracle peoplesoft" vendor-product pair plus another token → duplicate.
        let dedup = Deduplicator(
            existingFingerprints: [],
            recentTitles: ["Oracle mitigates PeopleSoft zero-day exploited in attacks"]
        )
        let article = makeArticle(title: "ShinyHunters hacked 100 orgs via Oracle PeopleSoft 0-day")
        XCTAssertTrue(dedup.isDuplicate(article))
    }

    private func makeArticle(title: String) -> RawArticle {
        RawArticle(guid: UUID().uuidString, title: title, summary: "",
                   url: URL(string: "https://example.com")!, source: .hackread,
                   publishedAt: Date(), categories: [])
    }
}
