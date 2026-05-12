import SwiftUI
import Charts
import SwiftData

struct SourceDistribution: View {
    @Query private var articles: [Article]

    private struct SourceCount: Identifiable {
        let source: FeedSource
        let count: Int
        var id: String { source.rawValue }
    }

    private var counts: [SourceCount] {
        FeedSource.allCases.map { source in
            SourceCount(source: source, count: articles.filter { $0.sourceRaw == source.rawValue }.count)
        }.filter { $0.count > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE DISTRIBUTION")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(alignment: .center, spacing: 16) {
                Chart(counts) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.55))
                        .foregroundStyle(item.source.accentColor)
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(counts) { item in
                        HStack(spacing: 6) {
                            Circle().fill(item.source.accentColor).frame(width: 7, height: 7)
                            Text(item.source.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}
