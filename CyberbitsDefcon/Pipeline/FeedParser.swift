import Foundation

enum FeedParser {

    static func parse(xmlData: Data, source: FeedSource) async throws -> [RawArticle] {
        let delegate = XMLFeedDelegate(source: source)
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.parse()
        return delegate.articles
    }

    static func parseSecurityAffairs(jsonData: Data) async throws -> [RawArticle] {
        let posts = try JSONDecoder().decode([SAPost].self, from: jsonData)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        return posts.compactMap { post -> RawArticle? in
            guard let date = formatter.date(from: post.date_gmt + "Z")
                       ?? fallback.date(from: post.date_gmt + "Z") else { return nil }
            let title = post.title.rendered.htmlStripped
            let summary = post.excerpt.rendered.htmlStripped
            guard let url = URL(string: post.link) else { return nil }
            return RawArticle(
                guid: String(post.id),
                title: title,
                summary: summary,
                url: url,
                source: .securityAffairs,
                publishedAt: date,
                categories: post.categories.map(String.init)
            )
        }
    }

    private struct SAPost: Decodable {
        let id: Int
        let title: RenderedField
        let excerpt: RenderedField
        let link: String
        let date_gmt: String
        let categories: [Int]
    }

    private struct RenderedField: Decodable {
        let rendered: String
    }
}

private final class XMLFeedDelegate: NSObject, XMLParserDelegate {
    let source: FeedSource
    var articles: [RawArticle] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentGuid = ""
    private var currentSummary = ""
    private var currentPubDate = ""
    private var currentCategories: [String] = []
    private var isInsideItem = false
    private var isAtom = false
    private var pendingAtomLink = ""

    private static let rssFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()
    private static let atomFormatter = ISO8601DateFormatter()

    init(source: FeedSource) { self.source = source }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        if currentElement == "feed" { isAtom = true }
        if currentElement == "item" || currentElement == "entry" {
            isInsideItem = true
            currentTitle = ""; currentLink = ""; currentGuid = ""
            currentSummary = ""; currentPubDate = ""; currentCategories = []
        }
        if isAtom && currentElement == "link", let href = attributes["href"], !href.isEmpty {
            pendingAtomLink = href
        }
        if currentElement == "category" {
            if let term = attributes["term"] { currentCategories.append(term) }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        switch currentElement {
        case "title":    currentTitle    += s
        case "link":     if !isAtom { currentLink += s }
        case "guid":     currentGuid     += s
        case "description", "summary": currentSummary += s
        case "pubdate", "published", "updated": currentPubDate += s
        case "category": currentCategories.append(s)
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let lower = elementName.lowercased()
        guard lower == "item" || lower == "entry" else { return }
        guard isInsideItem else { return }
        defer {
            isInsideItem = false
            currentTitle = ""; currentLink = ""; currentGuid = ""
            currentSummary = ""; currentPubDate = ""; currentCategories = []
            pendingAtomLink = ""
        }

        if isAtom && currentLink.isEmpty { currentLink = pendingAtomLink }
        if currentGuid.isEmpty { currentGuid = currentLink }

        guard !currentTitle.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: currentLink),
              !currentGuid.isEmpty else { return }

        let date: Date?
        if isAtom {
            date = Self.atomFormatter.date(from: currentPubDate)
        } else {
            date = Self.rssFormatter.date(from: currentPubDate)
        }
        guard let publishedAt = date else { return }

        articles.append(RawArticle(
            guid: currentGuid,
            title: currentTitle.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: currentSummary.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            source: source,
            publishedAt: publishedAt,
            categories: currentCategories
        ))
    }
}

extension String {
    var htmlStripped: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
