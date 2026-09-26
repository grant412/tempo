import AppKit

/// Lock, sleep, display sleep, and fast user switching.
@MainActor
final class SessionObserver {
    var onChange: (() -> Void)?
    private(set) var locked = false
    private(set) var asleep = false
    private(set) var displaysAsleep = false
    private(set) var inactive = false
    private var tokens: [NSObjectProtocol] = []

    var isAway: Bool { locked || asleep || displaysAsleep || inactive }

    func start() {
        let dnc = DistributedNotificationCenter.default()
        observe(dnc, "com.apple.screenIsLocked") { $0.locked = true }
        observe(dnc, "com.apple.screenIsUnlocked") { $0.locked = false }
        let wnc = NSWorkspace.shared.notificationCenter
        observe(wnc, NSWorkspace.willSleepNotification.rawValue) { $0.asleep = true }
        observe(wnc, NSWorkspace.didWakeNotification.rawValue) { $0.asleep = false }
        observe(wnc, NSWorkspace.screensDidSleepNotification.rawValue) { $0.displaysAsleep = true }
        observe(wnc, NSWorkspace.screensDidWakeNotification.rawValue) { $0.displaysAsleep = false }
        observe(wnc, NSWorkspace.sessionDidResignActiveNotification.rawValue) { $0.inactive = true }
        observe(wnc, NSWorkspace.sessionDidBecomeActiveNotification.rawValue) { $0.inactive = false }
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ apply: @escaping (SessionObserver) -> Void) {
        tokens.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                apply(self)
                self.onChange?()
            }
        })
    }
}
