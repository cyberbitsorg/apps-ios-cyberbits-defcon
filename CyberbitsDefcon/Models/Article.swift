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
    var isRead: Bool
    var readAt: Date?
    var fingerprint: String
    var triggerRaw: String?
    var tags: [String] = []

    init(guid: String, title: String, summary: String, url: URL,
         source: FeedSource, publishedAt: Date, defconScore: Double,
         fingerprint: String, trigger: TriggerType? = nil, tags: [String] = []) {
        self.guid = guid
        self.title = title
        self.summary = summary
        self.urlString = url.absoluteString
        self.sourceRaw = source.rawValue
        self.publishedAt = publishedAt
        self.defconScore = defconScore
        self.isRead = false
        self.readAt = nil
        self.fingerprint = fingerprint
        self.triggerRaw = trigger?.rawValue
        self.tags = tags
    }

    /// Malformed persisted URLs fall back to the Cyberbits homepage rather than
    /// shipping users off to a third-party placeholder domain.
    var url: URL { URL(string: urlString) ?? URL(string: "https://cyberbits.systems")! }
    var source: FeedSource { FeedSource(rawValue: sourceRaw) ?? .hackread }
    var trigger: TriggerType? {
        guard let triggerRaw else { return nil }
        return TriggerType(rawValue: triggerRaw)
    }
    var defconLevel: Int { Scorer.levelFromScore(defconScore) }
}
