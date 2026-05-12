import SwiftUI

enum DefconTrend { case rising, falling, stable }

struct DefconFactors {
    let volumeScore: Double
    let cveScore: Double
    let impactScore: Double
    let keywordScore: Double

    var total: Double { min(volumeScore + cveScore + impactScore + keywordScore, 100) }

    var level: Int {
        switch total {
        case 80...: return 5
        case 60..<80: return 4
        case 40..<60: return 3
        case 20..<40: return 2
        default: return 1
        }
    }
}

struct DefconStatus {
    let score: Double
    let level: Int
    let label: String
    let color: Color
    let factors: DefconFactors
    let trend: DefconTrend
    let computedAt: Date

    static let labels = [1: "LOW", 2: "GUARDED", 3: "ELEVATED", 4: "HIGH", 5: "CRITICAL"]

    init(factors: DefconFactors, trend: DefconTrend, computedAt: Date) {
        self.factors = factors
        self.score = factors.total
        self.level = factors.level
        self.label = DefconStatus.labels[factors.level] ?? "UNKNOWN"
        self.color = Color.defcon(factors.level)
        self.trend = trend
        self.computedAt = computedAt
    }
}
