import Foundation

/// Static relative-time formatter — produces strings like "Just now",
/// "5 min ago", "3 h ago", "2 d ago". Coarse enough that it doesn't
/// need to tick every second; render-time evaluation is sufficient.
enum RelativeTime {
    static func format(_ date: Date, reference: Date = Date()) -> String {
        let seconds = Int(reference.timeIntervalSince(date))
        switch seconds {
        case ..<0:
            return "Just now"
        case 0..<60:
            return "Just now"
        case 60..<3600:
            let minutes = seconds / 60
            return "\(minutes) min ago"
        case 3600..<86_400:
            let hours = seconds / 3600
            return "\(hours) h ago"
        default:
            let days = seconds / 86_400
            return "\(days) d ago"
        }
    }
}
