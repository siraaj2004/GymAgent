import Foundation
import UserNotifications

/// Local notifications only. No guilt-inducing wording, no excessive repeats:
/// one daily reminder, one 30-minute warning, one rest-day message, one completion message.
enum NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleDaily(gymTime: Date, dayTitle: String?, isRestDay: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["gym-daily", "gym-30min", "gym-rest"])
        let comps = Calendar.current.dateComponents([.hour, .minute], from: gymTime)
        let daily = UNMutableNotificationContent()
        daily.title = "GYM AI"
        daily.body = isRestDay ? "Today is recovery day. Focus on sleep, nutrition and hydration."
            : "Time for your workout! Today is \(dayTitle ?? "your training day")."
        daily.sound = .default
        center.add(UNNotificationRequest(identifier: "gym-daily", content: daily,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        if !isRestDay, let before = Calendar.current.date(byAdding: .minute, value: -30, to: gymTime) {
            let warn = UNMutableNotificationContent()
            warn.title = "GYM AI"
            warn.body = "Your gym session starts in 30 minutes."
            warn.sound = .default
            let c = Calendar.current.dateComponents([.hour, .minute], from: before)
            center.add(UNNotificationRequest(identifier: "gym-30min", content: warn,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
        }
    }

    static func completionMessage() {
        let content = UNMutableNotificationContent()
        content.title = "GYM AI"
        content.body = "Excellent work! Your session has been saved."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "gym-done", content: content, trigger: nil))
    }

    static func snooze(minutes: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = "GYM AI"
        content.body = "Your workout reminder, snoozed."
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "gym-snooze", content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)))
    }
}
