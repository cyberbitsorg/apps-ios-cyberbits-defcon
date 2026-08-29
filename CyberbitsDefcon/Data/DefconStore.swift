import Foundation
import SwiftData

enum DefconStore {

    /// `displayedLevel` is the sticky-adjusted level (not the raw `levelFromScore`).
    /// The score field stays raw so trends remain comparable; the level field is
    /// what the UI shows.
    static func writeHistory(_ global: GlobalScoreResult,
                             displayedLevel: Int? = nil,
                             context: ModelContext) {
        let level = displayedLevel ?? Scorer.levelFromScore(global.score)
        let entry = DefconHistory(
            score: global.score,
            level: level,
            computedAt: Date(),
            weightedMax: global.weightedMax,
            volumeBonus: global.volumeBonus,
            trigger: global.trigger,
            triggerArticleTitle: global.triggerArticleTitle,
            triggerArticlePublishedAt: global.triggerArticlePublishedAt
        )
        context.insert(entry)
    }

    static func currentStatus(context: ModelContext) throws -> DefconStatus? {
        var descriptor = FetchDescriptor<DefconHistory>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 2
        let entries = try context.fetch(descriptor)
        guard let latest = entries.first else { return nil }
        let previous = entries.count > 1 ? entries[1] : nil

        // In the inverted scale, a HIGHER level number is a LOWER threat.
        // So "rising threat" = level number decreasing.
        let trend: DefconTrend
        if let prev = previous {
            if latest.level < prev.level { trend = .rising }
            else if latest.level > prev.level { trend = .falling }
            else { trend = .stable }
        } else {
            trend = .stable
        }

        let breakdown = DefconBreakdown(
            weightedMax: latest.weightedMax,
            volumeBonus: latest.volumeBonus,
            trigger: latest.trigger,
            triggerArticleTitle: latest.triggerArticleTitle,
            triggerArticlePublishedAt: latest.triggerArticlePublishedAt
        )
        return DefconStatus(breakdown: breakdown,
                            trend: trend,
                            computedAt: latest.computedAt,
                            displayedLevel: latest.level)
    }
}
