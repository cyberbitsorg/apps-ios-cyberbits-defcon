import SwiftUI
import SwiftData

struct RecentCVEs: View {
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    private var cves: [(id: String, url: URL)] {
        let pattern = try? NSRegularExpression(pattern: #"CVE-\d{4}-\d{4,}"#, options: .caseInsensitive)
        var seen = Set<String>()
        var result: [(String, URL)] = []
        for article in articles.prefix(50) {
            let text = "\(article.title) \(article.summary)"
            let range = NSRange(text.startIndex..., in: text)
            let matches = pattern?.matches(in: text, range: range) ?? []
            for match in matches {
                if let r = Range(match.range, in: text) {
                    let cve = String(text[r]).uppercased()
                    if seen.insert(cve).inserted {
                        let urlString = "https://nvd.nist.gov/vuln/detail/\(cve)"
                        if let url = URL(string: urlString) {
                            result.append((cve, url))
                        }
                    }
                }
            }
            if result.count >= 10 { break }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT CVEs")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            if cves.isEmpty {
                Text("No CVEs detected in current articles")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                CVEChipFlow(cves: Array(cves.prefix(8)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
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

private struct CVEChipFlow: View {
    let cves: [(id: String, url: URL)]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(cves, id: \.id) { cve in
                CVEChip(id: cve.id, url: cve.url)
            }
        }
    }
}
