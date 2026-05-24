import Foundation
import SwiftData

@Model
final class DefconHistory {
    var score: Double
    var level: Int
    var computedAt: Date
    var weightedMax: Double
    var volumeBonus: Double
    var triggerRaw: String?
    var triggerArticleTitle: String?
    var triggerArticlePublishedAt: Date?

    init(score: Double, level: Int, computedAt: Date,
         weightedMax: Double, volumeBonus: Double,
         trigger: TriggerType? = nil,
         triggerArticleTitle: String? = nil,
         triggerArticlePublishedAt: Date? = nil) {
        self.score = score
        self.level = level
        self.computedAt = computedAt
        self.weightedMax = weightedMax
        self.volumeBonus = volumeBonus
        self.triggerRaw = trigger?.rawValue
        self.triggerArticleTitle = triggerArticleTitle
        self.triggerArticlePublishedAt = triggerArticlePublishedAt
    }

    var trigger: TriggerType? {
        guard let triggerRaw else { return nil }
        return TriggerType(rawValue: triggerRaw)
    }
}
