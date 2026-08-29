import SwiftUI

enum DefconTrend {
    case rising, falling, stable

    /// Title-case label (e.g. "Rising"); uppercase at the call site where needed.
    var label: String {
        switch self {
        case .rising:  return "Rising"
        case .falling: return "Falling"
        case .stable:  return "Stable"
        }
    }

    var color: Color {
        switch self {
        case .rising:  return Color(hex: "ef4444")
        case .falling: return Color(hex: "22c55e")
        case .stable:  return .secondary
        }
    }

    var iconName: String {
        switch self {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return "arrow.right"
        }
    }
}

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
