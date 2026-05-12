import Foundation

struct RawArticle {
    let guid: String
    let title: String
    let summary: String
    let url: URL
    let source: FeedSource
    let publishedAt: Date
    let categories: [String]
}
