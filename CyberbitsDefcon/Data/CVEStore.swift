import Foundation
import SwiftData

enum CVEStore {
    /// Matches docker `CVE_TTL = 36 * 3600`.
    static let ttl: TimeInterval = 36 * 3600

    /// All CVE IDs still within their 36h window.
    static func recentCVEs(context: ModelContext, now: Date = Date()) -> Set<String> {
        let cutoff = now.addingTimeInterval(-ttl)
        let descriptor = FetchDescriptor<CVERecord>(
            predicate: #Predicate { $0.seenAt >= cutoff }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return Set(all.map(\.cveId))
    }

    /// Insert a CVE if it doesn't exist; refresh its timestamp if it does.
    static func record(_ cve: String, context: ModelContext, now: Date = Date()) {
        let id = cve
        var existing = FetchDescriptor<CVERecord>(predicate: #Predicate { $0.cveId == id })
        existing.fetchLimit = 1
        if let found = (try? context.fetch(existing))?.first {
            found.seenAt = now
        } else {
            context.insert(CVERecord(cveId: cve, seenAt: now))
        }
    }

    /// Drop CVEs older than the TTL.
    static func trim(context: ModelContext, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-ttl)
        let descriptor = FetchDescriptor<CVERecord>(
            predicate: #Predicate { $0.seenAt < cutoff }
        )
        let stale = (try? context.fetch(descriptor)) ?? []
        for r in stale { context.delete(r) }
    }
}
