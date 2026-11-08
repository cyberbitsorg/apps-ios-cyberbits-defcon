import XCTest
import SwiftData
@testable import CyberbitsDefcon

/// Ports of docker `services/news-aggregator/tests/test_tagger.py`.
final class TaggerTests: XCTestCase {

    func test_ransomwareHeadline() {
        let tags = Tagger.classifyTags(
            title: "Qilin ransomware claims attack on US healthcare organization",
            summary: "The gang listed the victim on its leak site and is demanding a ransom."
        )
        XCTAssertEqual(tags, ["ransomware", "attacks"])
    }

    func test_vulnerabilityHeadline() {
        let tags = Tagger.classifyTags(
            title: "CVE-2025-12345: critical RCE flaw in Cisco ASA firewall",
            summary: "A remote code execution vulnerability patched in the latest advisory."
        )
        XCTAssertEqual(tags, ["vulnerabilities"])
    }

    func test_malwareHeadline() {
        let tags = Tagger.classifyTags(
            title: "New Amos infostealer targets macOS users",
            summary: "The stealer harvests credentials and crypto wallets from browsers."
        )
        XCTAssertEqual(tags, ["malware"])
    }

    func test_breachHeadline() {
        let tags = Tagger.classifyTags(
            title: "Data breach at retailer exposes 3 million customer records",
            summary: "The company confirmed leaked payment data in a security notice."
        )
        XCTAssertEqual(tags, ["breaches"])
    }

    func test_aptHeadline() {
        let tags = Tagger.classifyTags(
            title: "Lazarus hackers target nuclear researchers in espionage campaign",
            summary: "The state-sponsored group used custom malware against the defense sector."
        )
        XCTAssertEqual(tags.first, "apt")
    }

    func test_fraudHeadline() {
        let tags = Tagger.classifyTags(
            title: "Pig butchering scams drain victims of millions",
            summary: "Fraud networks launder stolen funds through shell companies."
        )
        XCTAssertEqual(tags.first, "fraud")
    }

    func test_privacyHeadline() {
        let tags = Tagger.classifyTags(
            title: "GDPR ruling fines company over illegal tracking of personal data",
            summary: "The regulator found surveillance practices violated data protection law."
        )
        XCTAssertEqual(tags, ["privacy"])
    }

    func test_aiHeadline_withFraudOverlap() {
        let tags = Tagger.classifyTags(
            title: "Hackers use AI-generated deepfakes in BEC campaign",
            summary: "Artificial intelligence tools cloned an executive's voice to authorize transfers."
        )
        XCTAssertEqual(tags, ["ai", "fraud"])
    }

    func test_supplyChainHeadline() {
        let tags = Tagger.classifyTags(
            title: "Malicious npm package steals secrets in supply chain attack",
            summary: "The malicious dependency was downloaded thousands of times per week."
        )
        XCTAssertEqual(tags, ["supply-chain", "attacks"])
    }

    func test_cloudHeadline() {
        let tags = Tagger.classifyTags(
            title: "Azure cloud storage buckets leave data publicly accessible",
            summary: "Misconfigured S3 buckets exposed internal documents online."
        )
        XCTAssertEqual(tags.first, "cloud")
    }

    func test_icsOtHeadline() {
        let tags = Tagger.classifyTags(
            title: "Hackers breach water treatment facility SCADA systems",
            summary: "Critical infrastructure operators warned utilities about the intrusion."
        )
        XCTAssertEqual(tags, ["ics-ot", "breaches"])
    }

    func test_maxThreeTags() {
        let tags = Tagger.classifyTags(
            title: "Ransomware attack on water utility exploits CVE pitched by AI chatbot",
            summary: "Extortion leak site posting follows phishing wave against cloud tenants."
        )
        XCTAssertEqual(tags.count, Tagger.maxTags)
    }

    func test_titleMatch_outranksSummaryMatch() {
        let tags = Tagger.classifyTags(title: "Data breach at retailer", summary: "GDPR discussion follows.")
        XCTAssertEqual(tags, ["breaches", "privacy"])
    }

    func test_noMatch_returnsFallbackTag() {
        let tags = Tagger.classifyTags(title: "Tech stocks rally on earnings", summary: "Markets closed higher.")
        XCTAssertEqual(tags, [Vocabulary.fallbackTag])
    }

    func test_shortTokens_useWordBoundaries() {
        // "ai" must match "AI" but not inside "said"; "apt" not inside "capture".
        XCTAssertEqual(Tagger.classifyTags(title: "He said AI models were compared", summary: ""), ["ai"])
        XCTAssertEqual(Tagger.classifyTags(title: "The capture tool ran overnight", summary: ""),
                       [Vocabulary.fallbackTag])
    }

    func test_emptyInput_returnsFallbackTag() {
        XCTAssertEqual(Tagger.classifyTags(title: "", summary: ""), [Vocabulary.fallbackTag])
    }

    func test_upsert_persistsClassifiedTags() throws {
        // docker: normalizer stores classify_tags output and articles.py upserts it.
        let raw = RawArticle(guid: "tagged", title: "Ransomware attack hits hospital",
                             summary: "Breach under investigation.",
                             url: URL(string: "https://x.com")!, source: .hackread,
                             publishedAt: Date())
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Article.self, configurations: config)
        let context = ModelContext(container)

        let tags = Tagger.classifyTags(title: raw.title, summary: raw.summary)
        ArticleStore.upsert(raw, score: 42, tags: tags, context: context)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched[0].tags.contains("ransomware"))
    }
}
