import Foundation
import SwiftData

enum DedupStore {
    /// Matches docker `RECENT_TITLES_MAX = 300`.
    static let maxRecords = 300

    /// All persisted fingerprints (most recent first).
    static func fingerprints(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<DedupRecord>()
        let all = (try? context.fetch(descriptor)) ?? []
        return Set(all.map(\.fingerprint))
    }

    /// All persisted titles (most recent first), capped at `maxRecords`.
    static func recentTitles(context: ModelContext) -> [String] {
        var descriptor = FetchDescriptor<DedupRecord>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        descriptor.fetchLimit = maxRecords
        return ((try? context.fetch(descriptor)) ?? []).map(\.title)
    }

    /// Register a newly-accepted article in the dedup log. No-op if the fingerprint
    /// is already present (the `@Attribute(.unique)` would otherwise crash on save).
    static func record(fingerprint: String, title: String, context: ModelContext) {
        let fp = fingerprint
        var existing = FetchDescriptor<DedupRecord>(predicate: #Predicate { $0.fingerprint == fp })
        existing.fetchLimit = 1
        if (try? context.fetch(existing))?.isEmpty == false { return }
        context.insert(DedupRecord(fingerprint: fp, title: title))
    }

    /// Drop everything beyond the most recent `maxRecords` entries.
    static func trim(context: ModelContext) {
        let descriptor = FetchDescriptor<DedupRecord>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if all.count > maxRecords {
            all.dropFirst(maxRecords).forEach { context.delete($0) }
        }
    }
}
