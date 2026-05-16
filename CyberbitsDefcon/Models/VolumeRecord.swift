import Foundation
import SwiftData

/// One entry per refresh cycle: number of articles accepted that cycle.
/// Used to compute a rolling baseline (mean of last 168 entries) for the
/// volume bonus. Mirrors docker `cache/volume.py`.
@Model
final class VolumeRecord {
    var count: Int
    var recordedAt: Date

    init(count: Int, recordedAt: Date = Date()) {
        self.count = count
        self.recordedAt = recordedAt
    }
}
