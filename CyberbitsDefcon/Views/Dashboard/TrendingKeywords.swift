import SwiftUI
import SwiftData

struct TrendingKeywords: View {
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    // (keyword, severity tier 1–5, display color) — tier multiplies raw hit count to weight high-signal terms
    private static let tracked: [(String, Int, Color)] = [
        ("zero-day", 5, Color(hex: "dc2626")),
        ("ransomware", 4, Color(hex: "dc2626")),
        ("exploit", 3, Color(hex: "ea580c")),
        ("apt", 3, Color(hex: "ea580c")),
        ("vulnerability", 2, Color(hex: "f59e0b")),
        ("malware", 2, Color(hex: "f59e0b")),
        ("breach", 2, Color(hex: "f59e0b")),
        ("cve", 1, Color(hex: "3b82f6")),
        ("backdoor", 1, Color(hex: "3b82f6")),
        ("phishing", 1, Color(hex: "8b5cf6")),
        ("ddos", 1, Color(hex: "8b5cf6")),
        ("supply chain", 2, Color(hex: "ea580c")),
    ]

    private var keywords: [(word: String, count: Int, color: Color)] {
        let combined = articles.prefix(50).map { "\($0.title) \($0.summary)".lowercased() }.joined(separator: " ")
        return Self.tracked.compactMap { (kw, tier, color) in
            let count = combined.components(separatedBy: kw).count - 1
            return count > 0 ? (kw, count * tier, color) : nil
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRENDING KEYWORDS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            FlowLayout(spacing: 6) {
                ForEach(keywords.prefix(12), id: \.word) { kw in
                    Text(kw.word)
                        .font(.system(size: CGFloat(10 + min(kw.count / 2, 6))))
                        .foregroundStyle(kw.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(kw.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let w = subview.sizeThatFits(.unspecified).width
            if x + w > maxWidth && !rows.last!.isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(subview)
            x += w + spacing
        }
        return rows
    }
}
