import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter to turn "Remind Me" into an actual
/// system notification (banner + sound) at the chosen time, not just a
/// static entry in the Events card.
///
/// Note: local notifications from an unsigned, ad-hoc-built app can be
/// unreliable on some macOS versions/setups — if banners don't show up,
/// check System Settings → Notifications → Notchingale, and confirm the
/// permission prompt was actually granted on first launch.
final class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                debugLog("notification authorization error: \(error.localizedDescription)")
            } else {
                debugLog("notification authorization granted=\(granted)")
            }
        }
    }

    func scheduleReminder(taskID: UUID, title: String, at date: Date) {
        cancelReminder(taskID: taskID)
        guard date > Date() else { return } // don't schedule for the past

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: taskID.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                debugLog("failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    func cancelReminder(taskID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }

    /// Fires immediately (a ~0.1s trigger, since UNUserNotificationCenter
    /// has no true "post right now" API) — used when a focus timer hits
    /// 0:00 naturally, so you get a banner + sound even if the dashboard
    /// isn't open to see the pill change.
    func notifyFocusSessionComplete(taskTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = taskTitle.isEmpty ? "Time's up." : "\"\(taskTitle)\" — time's up."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-complete-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                debugLog("failed to post focus-complete notification: \(error.localizedDescription)")
            }
        }
    }
}
