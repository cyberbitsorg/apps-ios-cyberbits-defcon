import Foundation
import SwiftData

@Model
final class DefconHistory {
    var score: Double
    var level: Int
    var computedAt: Date
    var volumeScore: Double
    var cveScore: Double
    var impactScore: Double
    var keywordScore: Double

    init(score: Double, level: Int, computedAt: Date,
         volumeScore: Double, cveScore: Double,
         impactScore: Double, keywordScore: Double) {
        self.score = score
        self.level = level
        self.computedAt = computedAt
        self.volumeScore = volumeScore
        self.cveScore = cveScore
        self.impactScore = impactScore
        self.keywordScore = keywordScore
    }
}
