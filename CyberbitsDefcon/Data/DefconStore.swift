import Foundation
import SwiftData

enum DefconStore {

    static func writeHistory(_ global: GlobalScoreResult, context: ModelContext) {
        let level = Scorer.levelFromScore(global.score)
        let entry = DefconHistory(
            score: global.score,
            level: level,
            computedAt: Date(),
            weightedMax: global.weightedMax,
            volumeBonus: global.volumeBonus,
            trigger: global.trigger,
            triggerArticleTitle: global.triggerArticleTitle
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
            triggerArticleTitle: latest.triggerArticleTitle
        )
        return DefconStatus(breakdown: breakdown, trend: trend, computedAt: latest.computedAt)
    }

    static func history(hours: Int = 24, context: ModelContext) throws -> [DefconHistory] {
        let since = Date().addingTimeInterval(Double(-hours * 3600))
        let descriptor = FetchDescriptor<DefconHistory>(
            predicate: #Predicate { $0.computedAt >= since },
            sortBy: [SortDescriptor(\.computedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}
