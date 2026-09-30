import Foundation
import TempoCore
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Timer done notifications from before the corner pop-up (focus timer spec 3.3). None are
    /// posted now; clicking an old one in Notification Center still opens its session.
    nonisolated static let timerCategory = "timer-done"

    /// UNUserNotificationCenter needs a real app bundle; skip when run unbundled.
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func start() {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { Log.error("notification auth: \(error)") }
        }
    }

    func post(_ nudge: Nudge) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = NudgeCopy.title(nudge)
        content.body = NudgeCopy.body(nudge)
        content.sound = .default
        let id = "nudge-\(nudge.kind.rawValue)-\(Int(nudge.at.timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
            if let error { Log.error("post nudge: \(error)") }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        // An old timer done notification opens that session; nudges open the timeline.
        let sessionID = content.categoryIdentifier == Self.timerCategory
            ? (content.userInfo["sessionID"] as? NSNumber)?.int64Value : nil
        Task { @MainActor in
            if let sessionID {
                WindowManager.shared.showFocusNotes(sessionID: sessionID)
            } else {
                TempoModel.shared.goToToday()
                WindowManager.shared.showTimeline()
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
