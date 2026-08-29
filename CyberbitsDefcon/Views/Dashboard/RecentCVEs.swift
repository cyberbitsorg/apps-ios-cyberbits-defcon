import SwiftUI
import SwiftData

struct RecentCVEs: View {
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    private var cves: [(id: String, url: URL)] {
        var seen = Set<String>()
        var result: [(String, URL)] = []
        for article in articles.prefix(50) {
            let text = "\(article.title) \(article.summary)"
            // Canonical IDs from the shared pipeline pattern (see Deduplicator.cvePattern).
            for cve in Deduplicator.extractCVEs(text).sorted() {
                if seen.insert(cve).inserted,
                   let url = URL(string: "https://nvd.nist.gov/vuln/detail/\(cve)") {
                    result.append((cve, url))
                }
            }
            if result.count >= 10 { break }
        }
        return result
    }

    var body: some View {
        DashboardCard(title: "RECENT CVEs") {
            if cves.isEmpty {
                Text("No CVEs detected in current articles")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(cves.prefix(8), id: \.id) { cve in
                        CVEChip(id: cve.id, url: cve.url)
                    }
                }
            }
        }
    }
}

private struct CVEChip: View {
    let id: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Text(id)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.defcon(5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Color.defcon(5).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.defcon(5).opacity(0.35), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
