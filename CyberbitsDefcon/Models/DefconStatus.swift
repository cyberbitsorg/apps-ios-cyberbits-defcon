import SwiftUI

enum DefconTrend { case rising, falling, stable }

/// Breakdown of the current global DEFCON score (v2).
struct DefconBreakdown {
    let weightedMax: Double         // 0–100
    let volumeBonus: Double         // 0–10
    let trigger: TriggerType?
    let triggerArticleTitle: String?
    let triggerArticlePublishedAt: Date?

    var total: Double { min(weightedMax + volumeBonus, 100) }

    /// Official DEFCON level (1 = highest threat, 5 = lowest).
    var level: Int { Scorer.levelFromScore(total) }
}

struct DefconStatus {
    let score: Double
    let level: Int        // 1 (highest) … 5 (lowest)
    let label: String
    let color: Color
    let breakdown: DefconBreakdown
    let trend: DefconTrend
    let computedAt: Date

    /// Official DEFCON convention: 1 = highest threat ("Cocked Pistol").
    /// Matches DEFCON_LEVELS in apps-docker-cyberbits-defcon/services/frontend/src/lib/constants.ts.
    static let labels: [Int: String] = [
        1: "COCKED PISTOL",
        2: "FAST PACE",
        3: "ROUND HOUSE",
        4: "DOUBLE TAKE",
        5: "FADE OUT",
    ]

    static func shortLabel(_ level: Int) -> String {
        // Short tags used by filter chips / pickers
        switch level {
        case 1: return "DEFCON 1"
        case 2: return "DEFCON 2"
        case 3: return "DEFCON 3"
        case 4: return "DEFCON 4"
        case 5: return "DEFCON 5"
        default: return "—"
        }
    }

    /// `displayedLevel` defaults to `breakdown.level` (raw) but can be overridden
    /// with the sticky-state-machine level so the UI reflects the displayed value.
    init(breakdown: DefconBreakdown, trend: DefconTrend, computedAt: Date, displayedLevel: Int? = nil) {
        let level = displayedLevel ?? breakdown.level
        self.breakdown = breakdown
        self.score = breakdown.total
        self.level = level
        self.label = DefconStatus.labels[level] ?? "UNKNOWN"
        self.color = Color.defcon(level)
        self.trend = trend
        self.computedAt = computedAt
    }
}
