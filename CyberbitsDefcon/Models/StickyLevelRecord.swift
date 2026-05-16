import Foundation
import SwiftData

/// Singleton row that holds the sticky-level state. Matches docker
/// `last_refresh.min_level_floor` / `min_level_until_at`.
@Model
final class StickyLevelRecord {
    /// Always 1 — used to enforce singleton semantics on lookups.
    @Attribute(.unique) var id: Int
    var floor: Int?
    var untilAt: Date?

    init(id: Int = 1, floor: Int? = nil, untilAt: Date? = nil) {
        self.id = id
        self.floor = floor
        self.untilAt = untilAt
    }
}
