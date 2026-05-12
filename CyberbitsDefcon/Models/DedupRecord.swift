import Foundation
import SwiftData

/// Persisted dedup state. Kept independently of `Article` so that trimming the
/// visible article list (capped at 100, matching the docker app) does not shrink
/// the dedup window. Mirrors the docker app's Redis `dedup:recent_titles` (300).
@Model
final class DedupRecord {
    @Attribute(.unique) var fingerprint: String
    var title: String
    var addedAt: Date

    init(fingerprint: String, title: String, addedAt: Date = Date()) {
        self.fingerprint = fingerprint
        self.title = title
        self.addedAt = addedAt
    }
}
