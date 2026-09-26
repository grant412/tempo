import Foundation
import TempoCore
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

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
        Task { @MainActor in
            TempoModel.shared.goToToday()
            WindowManager.shared.showTimeline()
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
