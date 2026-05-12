import Foundation
import SwiftData

enum DefconStore {

    static func writeHistory(factors: DefconFactors, context: ModelContext) {
        let entry = DefconHistory(
            score: factors.total, level: factors.level, computedAt: Date(),
            volumeScore: factors.volumeScore, cveScore: factors.cveScore,
            impactScore: factors.impactScore, keywordScore: factors.keywordScore
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

        let trend: DefconTrend
        if let prev = previous {
            if latest.level > prev.level { trend = .rising }
            else if latest.level < prev.level { trend = .falling }
            else { trend = .stable }
        } else {
            trend = .stable
        }

        let factors = DefconFactors(
            volumeScore: latest.volumeScore,
            cveScore: latest.cveScore,
            impactScore: latest.impactScore,
            keywordScore: latest.keywordScore
        )
        return DefconStatus(factors: factors, trend: trend, computedAt: latest.computedAt)
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
