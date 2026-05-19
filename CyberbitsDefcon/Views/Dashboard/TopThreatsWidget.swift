import SwiftUI
import SwiftData

struct TopThreatsWidget: View {
    // Pull the 20 most-recent articles, then surface the 5 highest-scoring
    // among those — matches the docker dashboard's "top threats" scope.
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    private var top5: [Article] {
        articles.prefix(20).sorted { $0.defconScore > $1.defconScore }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP THREATS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            ForEach(top5) { article in
                Link(destination: article.url) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.defcon(scoreLevel(article.defconScore)))
                            .frame(width: 3)
                            .cornerRadius(2)
                        Text(article.title)
                            .font(.caption)
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreLevel(_ score: Double) -> Int { Scorer.levelFromScore(score) }
}
