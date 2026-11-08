import XCTest
@testable import CyberbitsDefcon

/// Ports of the tag additions to docker
/// `services/news-aggregator/tests/test_vocabulary.py`.
final class VocabularyTests: XCTestCase {

    func test_tagKeywords_hasTaxonomyKeysInOrder() {
        let expected = [
            "attacks", "vulnerabilities", "malware", "ransomware", "breaches", "apt",
            "fraud", "privacy", "ai", "supply-chain", "cloud", "ics-ot",
        ]
        XCTAssertEqual(Vocabulary.tagKeywords.map(\.tag), expected)
    }

    func test_tagKeyword_listsNonEmpty() {
        for (_, keywords) in Vocabulary.tagKeywords {
            XCTAssertFalse(keywords.isEmpty)
        }
    }

    func test_tagKeywords_allLowercase() {
        for (tag, keywords) in Vocabulary.tagKeywords {
            for kw in keywords {
                XCTAssertEqual(kw, kw.lowercased(), "tagKeywords[\(tag)]: \(kw) not lowercase")
            }
        }
    }

    func test_tagWordBoundaryRequired_tokensExistInTagKeywords() {
        let allKeywords = Set(Vocabulary.tagKeywords.flatMap(\.keywords))
        for kw in Vocabulary.tagWordBoundaryRequired {
            XCTAssertTrue(allKeywords.contains(kw),
                          "\(kw) in tagWordBoundaryRequired but not in any tagKeywords list")
        }
    }

    func test_shortAmbiguousTagTokens_areWordBoundaryMatched() {
        // "ai" in "said", "apt" in "capture", "ics" in "physics", "bec" in "because",
        // "aws" in "lawsuit" — must not match as substrings.
        for kw in ["ai", "apt", "rat", "ics", "bec", "aws", "rce", "cve", "0-day"] {
            XCTAssertTrue(Vocabulary.tagWordBoundaryRequired.contains(kw),
                          "\(kw) must be in tagWordBoundaryRequired")
        }
    }

    func test_tagActorGroups_areSubsetOfThreatActors() {
        let actors = Set(Vocabulary.threatActors)
        for group in Vocabulary.ransomwareGroups + Vocabulary.aptGroups + Vocabulary.breachGroups {
            XCTAssertTrue(actors.contains(group), "\(group) not in threatActors")
        }
    }

    func test_tagKeywords_reuseActorGroups() {
        let keywords = Dictionary(uniqueKeysWithValues: Vocabulary.tagKeywords.map { ($0.tag, $0.keywords) })
        XCTAssertTrue(keywords["ransomware"]!.contains("lockbit"))
        XCTAssertTrue(keywords["apt"]!.contains("lazarus"))
        XCTAssertTrue(keywords["breaches"]!.contains("shinyhunters"))
    }

    func test_fallbackTag_notInTagKeywords() {
        // The fallback must never compete in the ranking — it only fills in after it.
        let tags = Vocabulary.tagKeywords.map(\.tag)
        XCTAssertFalse(tags.contains(Vocabulary.fallbackTag))
    }

    func test_tagDisplayLabels_coversAllTagsAndFallback() {
        var labels = Vocabulary.tagDisplayLabels
        for tag in Vocabulary.tagKeywords.map(\.tag) + [Vocabulary.fallbackTag] {
            XCTAssertNotNil(labels.removeValue(forKey: tag), "no display label for tag \(tag)")
        }
        XCTAssertTrue(labels.isEmpty, "tagDisplayLabels has stale keys: \(labels.keys)")
    }
}
