import XCTest
import SwiftData
@testable import CyberbitsDefcon

@MainActor
final class DataStoreTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Article.self, DefconHistory.self, configurations: config)
        context = ModelContext(container)
    }

    func test_upsert_insertsNewArticle() throws {
        let raw = RawArticle(guid: "abc", title: "Test", summary: "Sum",
                             url: URL(string: "https://x.com")!, source: .hackread,
                             publishedAt: Date(), categories: [])
        ArticleStore.upsert(raw, score: 55.0, context: context)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].guid, "abc")
        XCTAssertEqual(fetched[0].defconScore, 55.0)
    }

    func test_upsert_skipsExistingGuid() throws {
        let raw = RawArticle(guid: "abc", title: "Test", summary: "Sum",
                             url: URL(string: "https://x.com")!, source: .hackread,
                             publishedAt: Date(), categories: [])
        ArticleStore.upsert(raw, score: 55.0, context: context)
        ArticleStore.upsert(raw, score: 60.0, context: context)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(fetched.count, 1)
    }

    func test_trim_keepsOnlyNewest() throws {
        for i in 0..<20 {
            let raw = RawArticle(guid: "g\(i)", title: "Article \(i)", summary: "",
                                 url: URL(string: "https://x.com/\(i)")!, source: .hackread,
                                 publishedAt: Date().addingTimeInterval(Double(i)), categories: [])
            ArticleStore.upsert(raw, score: 50, context: context)
        }
        try context.save()
        ArticleStore.trim(totalLimit: 10, perSourceLimit: 15, context: context)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(fetched.count, 10)
    }

    func test_writeHistory_savesEntry() throws {
        let global = GlobalScoreResult(
            score: 72, weightedMax: 70, volumeBonus: 2,
            trigger: .activeExploitation, triggerArticleTitle: "Critical RCE in the wild"
        )
        DefconStore.writeHistory(global, context: context)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<DefconHistory>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].level, Scorer.levelFromScore(72)) // 72 → level 2 (HIGH)
        XCTAssertEqual(fetched[0].trigger, .activeExploitation)
    }

    func test_currentStatus_returnsNilWhenNoHistory() throws {
        let status = try DefconStore.currentStatus(context: context)
        XCTAssertNil(status)
    }
}
