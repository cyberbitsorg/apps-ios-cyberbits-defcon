import Foundation
import SwiftData

/// Persisted CVE-ID dedup state. Mirrors docker's Redis `dedup:cves:<id>` key with
/// a 36h TTL — long enough to span overnight news churn, short enough to allow
/// follow-up stories about the same CVE eventually.
@Model
final class CVERecord {
    @Attribute(.unique) var cveId: String
    var seenAt: Date

    init(cveId: String, seenAt: Date = Date()) {
        self.cveId = cveId
        self.seenAt = seenAt
    }
}
