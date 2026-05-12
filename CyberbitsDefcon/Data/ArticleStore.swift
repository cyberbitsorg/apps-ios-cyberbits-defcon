import Foundation
import SwiftData

enum ArticleStore {

    static func upsert(_ raw: RawArticle, score: Double, context: ModelContext) {
        let guid = raw.guid
        var descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.guid == guid })
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }

        let fp = Deduplicator.fingerprint(raw.title)
        let article = Article(guid: raw.guid, title: raw.title, summary: raw.summary,
                              url: raw.url, source: raw.source, publishedAt: raw.publishedAt,
                              defconScore: score, categories: raw.categories, fingerprint: fp)
        context.insert(article)
    }

    static func existingFingerprints(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Article>()
        let all = (try? context.fetch(descriptor)) ?? []
        return Set(all.map(\.fingerprint))
    }

    static func recentTitles(limit: Int = 300, context: ModelContext) -> [String] {
        var descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.title)
    }

    static func trim(totalLimit: Int = 100, perSourceLimit: Int = 15, context: ModelContext) {
        // Per-source trim
        for source in FeedSource.allCases {
            let raw = source.rawValue
            let descriptor = FetchDescriptor<Article>(
                predicate: #Predicate { $0.sourceRaw == raw },
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            let all = (try? context.fetch(descriptor)) ?? []
            if all.count > perSourceLimit {
                all.dropFirst(perSourceLimit).forEach { context.delete($0) }
            }
        }
        // Global trim
        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        if all.count > totalLimit {
            all.dropFirst(totalLimit).forEach { context.delete($0) }
        }
    }

    static func fetchRecent(limit: Int = 20, context: ModelContext) -> [Article] {
        var descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
