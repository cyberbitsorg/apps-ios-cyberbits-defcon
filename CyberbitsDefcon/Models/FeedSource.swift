import SwiftUI

enum FeedSource: String, CaseIterable, Identifiable {
    case hackread = "hackread"
    case infosecurityMagazine = "infosecurity_magazine"
    case securityAffairs = "security_affairs"
    case techRadar = "techradar"
    case theRegister = "the_register"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hackread: return "HackRead"
        case .infosecurityMagazine: return "Infosecurity Magazine"
        case .securityAffairs: return "Security Affairs"
        case .techRadar: return "TechRadar"
        case .theRegister: return "The Register"
        }
    }

    var feedURL: URL {
        switch self {
        case .hackread:
            return URL(string: "https://hackread.com/feed/")!
        case .infosecurityMagazine:
            return URL(string: "https://www.infosecurity-magazine.com/rss/news/")!
        case .securityAffairs:
            return URL(string: "https://securityaffairs.com/wp-json/wp/v2/posts?per_page=100")!
        case .techRadar:
            return URL(string: "https://www.techradar.com/feeds/tag/security")!
        case .theRegister:
            return URL(string: "https://www.theregister.com/security/headlines.atom")!
        }
    }

    var accentColor: Color {
        switch self {
        case .hackread: return Color(hex: "3b82f6")
        case .infosecurityMagazine: return Color(hex: "8b5cf6")
        case .securityAffairs: return Color(hex: "ec4899")
        case .techRadar: return Color(hex: "14b8a6")
        case .theRegister: return Color(hex: "f59e0b")
        }
    }

    var isJSONAPI: Bool { self == .securityAffairs }
}
