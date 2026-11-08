import Foundation
import SwiftData

enum ArticleStore {

    /// Callers that already computed the title fingerprint (the fetch pipeline)
    /// pass it in; otherwise it is derived from the title here.
    static func upsert(_ raw: RawArticle, score: Double, trigger: TriggerType? = nil,
                       fingerprint: String? = nil, tags: [String] = [], context: ModelContext) {
        let guid = raw.guid
        var descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.guid == guid })
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }

        let fp = fingerprint ?? Deduplicator.fingerprint(raw.title)
        let article = Article(guid: raw.guid, title: raw.title, summary: raw.summary,
                              url: raw.url, source: raw.source, publishedAt: raw.publishedAt,
                              defconScore: score,
                              fingerprint: fp, trigger: trigger, tags: tags)
        context.insert(article)
    }

    static func existingGuids(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Article>()
        let all = (try? context.fetch(descriptor)) ?? []
        return Set(all.map(\.guid))
    }

    static func trim(totalLimit: Int = 100, perSourceLimit: Int = 20, context: ModelContext) {
        // Single fetch sorted newest-first; partition in-memory to avoid SwiftData
        // predicate-capture quirks and to guarantee a single transactional delete pass.
        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        guard !all.isEmpty else { return }

        var keptPerSource: [String: Int] = [:]
        var keptTotal = 0
        for article in all {
            let perSource = keptPerSource[article.sourceRaw, default: 0]
            let withinPerSource = perSource < perSourceLimit
            let withinGlobal = keptTotal < totalLimit
            if withinPerSource && withinGlobal {
                keptPerSource[article.sourceRaw] = perSource + 1
                keptTotal += 1
            } else {
                context.delete(article)
            }
        }
    }

    static func fetchRecent(limit: Int = 20, context: ModelContext) -> [Article] {
        var descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
