import Foundation
import TempoCore
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    nonisolated static let timerCategory = "timer-done"
    nonisolated static let writeNotesAction = "write-notes"

    /// UNUserNotificationCenter needs a real app bundle; skip when run unbundled.
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func start() {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let write = UNNotificationAction(identifier: Self.writeNotesAction,
                                         title: "Write down what you got done", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.timerCategory, actions: [write],
                                   intentIdentifiers: [], options: []),
        ])
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

    /// "Timer done", "25 min, 2:10 PM to 2:35 PM", with a button to write notes (focus timer spec 3.3).
    func postTimerDone(_ session: FocusSession) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = "\(Format.minutesLabel(session.planned)), \(Format.clock(session.start)) to \(Format.clock(session.end))"
        content.sound = .default
        content.categoryIdentifier = Self.timerCategory
        content.userInfo = ["sessionID": session.id]
        let request = UNNotificationRequest(identifier: "timer-\(session.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { Log.error("post timer done: \(error)") }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        // The button and a click on the banner both open the notes for a timer.
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
