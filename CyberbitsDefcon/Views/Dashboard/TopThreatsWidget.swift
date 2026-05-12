import SwiftUI
import SwiftData

struct TopThreatsWidget: View {
    @Query(sort: \Article.defconScore, order: .reverse) private var articles: [Article]

    private var top5: [Article] { Array(articles.prefix(5)) }

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
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreLevel(_ score: Double) -> Int {
        switch score {
        case 80...: return 5; case 60..<80: return 4; case 40..<60: return 3
        case 20..<40: return 2; default: return 1
        }
    }
}
