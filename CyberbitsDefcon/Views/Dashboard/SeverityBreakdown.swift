import SwiftUI
import Charts
import SwiftData

struct SeverityBreakdown: View {
    @Query private var articles: [Article]

    private struct LevelCount: Identifiable {
        let level: Int
        let count: Int
        var id: Int { level }
        var label: String { ["", "LOW", "GUARDED", "ELEVATED", "HIGH", "CRITICAL"][level] }
        var color: Color { .defcon(level) }
    }

    private var counts: [LevelCount] {
        (1...5).map { level in
            let count = articles.filter { scoreLevel($0.defconScore) == level }.count
            return LevelCount(level: level, count: count)
        }
    }

    private func scoreLevel(_ score: Double) -> Int {
        switch score {
        case 80...: return 5
        case 60..<80: return 4
        case 40..<60: return 3
        case 20..<40: return 2
        default: return 1
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
