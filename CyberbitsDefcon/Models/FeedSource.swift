import SwiftUI

enum FeedSource: String, CaseIterable, Identifiable {
    case bleepingComputer = "bleeping_computer"
    case theHackerNews    = "hacker_news"
    case hackread         = "hackread"
    case securityAffairs  = "security_affairs"
    case theRegister      = "the_register"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bleepingComputer: return "Bleeping Computer"
        case .theHackerNews:    return "Hacker News"
        case .hackread:         return "HackRead"
        case .securityAffairs:  return "Security Affairs"
        case .theRegister:      return "The Register"
        }
    }

    var feedURL: URL {
        switch self {
        case .bleepingComputer:
            return URL(string: "https://www.bleepingcomputer.com/feed/")!
        case .theHackerNews:
            return URL(string: "https://thehackernews.com/feeds/posts/default")!
        case .hackread:
            return URL(string: "https://hackread.com/feed/")!
        case .securityAffairs:
            return URL(string: "https://securityaffairs.com/wp-json/wp/v2/posts?per_page=100")!
        case .theRegister:
            return URL(string: "https://www.theregister.com/security/headlines.atom")!
        }
    }

    /// Badge abbreviations — matches docker `services/frontend/src/lib/constants.ts` SOURCE_LABELS.
    var abbreviation: String {
        switch self {
        case .bleepingComputer: return "BC"
        case .theHackerNews:    return "HN"
        case .hackread:         return "HR"
        case .securityAffairs:  return "SA"
        case .theRegister:      return "TR"
        }
    }

    /// Source colors — muted slate palette, deliberately distinct from the DEFCON warning
    /// palette (white/red/yellow/green/blue) so source badges don't read as severity.
    /// Matches docker `services/frontend/src/lib/constants.ts` SOURCE_COLORS.
    var accentColor: Color {
        switch self {
        case .bleepingComputer: return Color(hex: "cbd5e1")   // slate-300 — lightest
        case .theHackerNews:    return Color(hex: "94a3b8")   // slate-400
        case .hackread:         return Color(hex: "64748b")   // slate-500
        case .securityAffairs:  return Color(hex: "475569")   // slate-600
        case .theRegister:      return Color(hex: "334155")   // slate-700 — darkest
        }
    }

    var isJSONAPI: Bool { self == .securityAffairs }
}
