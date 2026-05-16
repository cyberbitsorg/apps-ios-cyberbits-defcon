import SwiftUI
import Charts
import SwiftData

struct SeverityBreakdown: View {
    // Only the 20 most-recent articles drive the breakdown — matches the
    // docker reference where the dashboard reflects active threats.
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]
    private var recent: [Article] { Array(articles.prefix(20)) }

    private struct LevelCount: Identifiable {
        let level: Int
        let count: Int
        var id: Int { level }
        // Short axis labels — full terms ("Cocked Pistol" etc.) don't fit.
        var label: String { "DEF \(level)" }
        var color: Color { .defcon(level) }
    }

    private var counts: [LevelCount] {
        // Ordered highest threat (1) to lowest (5) for left-to-right severity ranking.
        (1...5).map { level in
            let count = recent.filter { Scorer.levelFromScore($0.defconScore) == level }.count
            return LevelCount(level: level, count: count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEVERITY BREAKDOWN")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            Chart(counts) { item in
                BarMark(x: .value("Level", item.label),
                        y: .value("Count", item.count))
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80)
        }
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}
