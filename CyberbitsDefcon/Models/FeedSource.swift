import SwiftUI

enum FeedSource: String, CaseIterable, Identifiable {
    case bleepingComputer = "bleeping_computer"
    case hackerNews       = "hacker_news"
    case hackread         = "hackread"
    case securityAffairs  = "security_affairs"
    case theRegister      = "the_register"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bleepingComputer: return "Bleeping Computer"
        case .hackerNews:       return "Hacker News"
        case .hackread:         return "HackRead"
        case .securityAffairs:  return "Security Affairs"
        case .theRegister:      return "The Register"
        }
    }

    var feedURL: URL {
        switch self {
        case .bleepingComputer:
            return URL(string: "https://www.bleepingcomputer.com/feed/")!
        case .hackerNews:
            return URL(string: "https://thehackernews.com/feeds/posts/default")!
        case .hackread:
            return URL(string: "https://hackread.com/feed/")!
        case .securityAffairs:
            return URL(string: "https://securityaffairs.com/wp-json/wp/v2/posts?per_page=100")!
        case .theRegister:
            return URL(string: "https://www.theregister.com/security/headlines.atom")!
        }
    }

    /// Source colors — matches docker `services/frontend/src/lib/constants.ts`.
    var accentColor: Color {
        switch self {
        case .bleepingComputer: return Color(hex: "f97316")   // orange
        case .hackerNews:       return Color(hex: "8b5cf6")   // violet
        case .hackread:         return Color(hex: "ec4899")   // pink
        case .securityAffairs:  return Color(hex: "e11d48")   // rose
        case .theRegister:      return Color(hex: "06b6d4")   // cyan
        }
    }

    var isJSONAPI: Bool { self == .securityAffairs }
}
