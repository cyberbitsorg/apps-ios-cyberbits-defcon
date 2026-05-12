import Foundation
import SwiftData

@Model
final class Article {
    @Attribute(.unique) var guid: String
    var title: String
    var summary: String
    var urlString: String
    var sourceRaw: String
    var publishedAt: Date
    var defconScore: Double
    var categories: [String]
    var isRead: Bool
    var readAt: Date?
    var fingerprint: String

    init(guid: String, title: String, summary: String, url: URL,
         source: FeedSource, publishedAt: Date, defconScore: Double,
         categories: [String], fingerprint: String) {
        self.guid = guid
        self.title = title
        self.summary = summary
        self.urlString = url.absoluteString
        self.sourceRaw = source.rawValue
        self.publishedAt = publishedAt
        self.defconScore = defconScore
        self.categories = categories
        self.isRead = false
        self.readAt = nil
        self.fingerprint = fingerprint
    }

    var url: URL { URL(string: urlString) ?? URL(string: "https://example.com")! }
    var source: FeedSource { FeedSource(rawValue: sourceRaw) ?? .hackread }
}
