import Foundation
import SwiftData

/// Rolling window of per-refresh article counts. Matches docker `cache/volume.py`.
enum VolumeStore {
    static let windowSize = 168
    static let coldStartMin = 3
    static let poisonMultiplier: Double = 3.0

    /// Mean of recent counts, or nil if there are fewer than `coldStartMin` entries.
    static func baseline(context: ModelContext) -> Double? {
        let descriptor = FetchDescriptor<VolumeRecord>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let recent = Array(all.prefix(windowSize))
        guard recent.count >= coldStartMin else { return nil }
        let total = recent.reduce(0.0) { $0 + Double($1.count) }
        return total / Double(recent.count)
    }

    /// Push a new count. Skipped if `count` would poison the baseline
    /// (>3× current mean — typical of cold-start dumps).
    static func record(_ count: Int, context: ModelContext) {
        if let base = baseline(context: context), base > 0,
           Double(count) > poisonMultiplier * base {
            return
        }
        context.insert(VolumeRecord(count: count))
    }

    /// Drop entries beyond the most recent `windowSize`.
    static func trim(context: ModelContext) {
        let descriptor = FetchDescriptor<VolumeRecord>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if all.count > windowSize {
            all.dropFirst(windowSize).forEach { context.delete($0) }
        }
    }
}
