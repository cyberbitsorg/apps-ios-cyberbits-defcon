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
                ForEach(cves.prefix(8), id: \.id) { cve in
                    Link(cve.id, destination: cve.url)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(hex: "3b82f6"))
                }
            }
        }
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}
