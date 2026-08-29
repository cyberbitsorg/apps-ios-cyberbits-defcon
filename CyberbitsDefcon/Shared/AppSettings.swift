import Foundation

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0, light = 1, dark = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum AppSettings {
    /// Single source of truth for UserDefaults keys and default values —
    /// `@AppStorage` call sites reference these instead of re-hardcoding them.
    enum Keys {
        static let appearance = "appearance"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let defconNotificationsEnabled = "defconNotificationsEnabled"
        static let notificationThreshold = "notificationThreshold"
        static let newArticleNotificationsEnabled = "newArticleNotificationsEnabled"
        static let lastRefreshedAt = "lastRefreshedAt"
    }

    static let defaultRefreshIntervalMinutes = 60
    static let defaultNotificationThreshold = 3

    private static let defaults = UserDefaults.standard

    static var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.integer(forKey: Keys.appearance)) ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Keys.appearance) }
    }

    static var refreshIntervalMinutes: Int {
        get {
            let v = defaults.integer(forKey: Keys.refreshIntervalMinutes)
            return v == 0 ? defaultRefreshIntervalMinutes : v
        }
        set { defaults.set(newValue, forKey: Keys.refreshIntervalMinutes) }
    }
    static var defconNotificationsEnabled: Bool {
        get { defaults.object(forKey: Keys.defconNotificationsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.defconNotificationsEnabled) }
    }
    static var notificationThreshold: Int {
        get {
            let v = defaults.integer(forKey: Keys.notificationThreshold)
            return v == 0 ? defaultNotificationThreshold : v
        }
        set { defaults.set(newValue, forKey: Keys.notificationThreshold) }
    }
    static var newArticleNotificationsEnabled: Bool {
        get { defaults.object(forKey: Keys.newArticleNotificationsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.newArticleNotificationsEnabled) }
    }
    static var lastRefreshedAt: Date? {
        get {
            let t = defaults.double(forKey: Keys.lastRefreshedAt)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.lastRefreshedAt) }
    }
    static var needsRefresh: Bool {
        guard let last = lastRefreshedAt else { return true }
        return Date().timeIntervalSince(last) > Double(refreshIntervalMinutes * 60)
    }
}
