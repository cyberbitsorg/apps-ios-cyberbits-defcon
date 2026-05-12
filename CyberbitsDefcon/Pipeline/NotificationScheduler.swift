import Foundation
import UserNotifications

enum NotificationScheduler {

    static func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func notifyDefconLevelChange(newLevel: Int, label: String) {
        // Inverted scale: notify when level ≤ threshold (lower number = higher threat).
        guard AppSettings.defconNotificationsEnabled,
              newLevel <= AppSettings.notificationThreshold else { return }

        let content = UNMutableNotificationContent()
        content.title = "DEFCON \(newLevel) — \(label)"
        content.body = "Threat level has risen. Tap to see the latest threats."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "defcon-level-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func notifyNewArticles(count: Int) {
        guard AppSettings.newArticleNotificationsEnabled, count > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Security Threats"
        content.body = "\(count) new article\(count == 1 ? "" : "s") found in the latest scan."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "new-articles-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
