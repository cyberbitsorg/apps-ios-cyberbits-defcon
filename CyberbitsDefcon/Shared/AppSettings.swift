import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    static var refreshIntervalMinutes: Int {
        get { let v = defaults.integer(forKey: "refreshIntervalMinutes"); return v == 0 ? 60 : v }
        set { defaults.set(newValue, forKey: "refreshIntervalMinutes") }
    }
    static var defconNotificationsEnabled: Bool {
        get { defaults.object(forKey: "defconNotificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "defconNotificationsEnabled") }
    }
    static var notificationThreshold: Int {
        get { let v = defaults.integer(forKey: "notificationThreshold"); return v == 0 ? 3 : v }
        set { defaults.set(newValue, forKey: "notificationThreshold") }
    }
    static var newArticleNotificationsEnabled: Bool {
        get { defaults.object(forKey: "newArticleNotificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "newArticleNotificationsEnabled") }
    }
    static var lastRefreshedAt: Date? {
        get {
            let t = defaults.double(forKey: "lastRefreshedAt")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "lastRefreshedAt") }
    }
    static var needsRefresh: Bool {
        guard let last = lastRefreshedAt else { return true }
        return Date().timeIntervalSince(last) > Double(refreshIntervalMinutes * 60)
    }
}
