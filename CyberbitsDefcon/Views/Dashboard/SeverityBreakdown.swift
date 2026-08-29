import SwiftUI
import SwiftData

/// Tappable severity bars — clicking a bar filters the Articles tab to that
/// DEFCON level, matching docker's SeverityBreakdown widget behaviour.
struct SeverityBreakdown: View {
    @Environment(AppState.self) private var appState

    // Only the 20 most-recent articles drive the breakdown — matches the
    // docker reference where the dashboard reflects active threats.
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]
    private var recent: [Article] { Array(articles.prefix(20)) }

    private struct LevelCount: Identifiable {
        let level: Int
        let count: Int
        var id: Int { level }
        var label: String { "DEF \(level)" }
        var color: Color { .defcon(level) }
    }

    private var counts: [LevelCount] {
        (1...5).map { level in
            let count = recent.filter { Scorer.levelFromScore($0.defconScore) == level }.count
            return LevelCount(level: level, count: count)
        }
    }

    private var maxCount: Int { max(counts.map(\.count).max() ?? 1, 1) }

    var body: some View {
        DashboardCard(title: "SEVERITY BREAKDOWN") {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(counts) { item in
                    Button {
                        appState.articleSeverityFilter =
                            appState.articleSeverityFilter == item.level ? nil : item.level
                        appState.selectedTab = .articles
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(item.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color.opacity(
                                    appState.articleSeverityFilter == item.level ? 1.0 : 0.85
                                ))
                                .frame(height: max(8, 56 * (Double(item.count) / Double(maxCount))))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(item.color,
                                                lineWidth: appState.articleSeverityFilter == item.level ? 2 : 0)
                                )
                                .shadow(color: item.level == 1 ? Color(hex: "dc2626").opacity(0.5) : .clear,
                                        radius: item.level == 1 ? 4 : 0)
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
    }
}
