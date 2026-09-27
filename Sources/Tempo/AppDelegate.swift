import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Held for the app's lifetime so App Nap never throttles the 5 s tick. It must not
    /// disable display sleep: IdleReader counts display-sleep assertions as presence.
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let me = NSRunningApplication.current
        if let id = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .filter { $0.processIdentifier != me.processIdentifier }
            if let other = others.first {
                other.activate()
                exit(0)
            }
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Tempo tracks activity every 5 seconds")
        let model = TempoModel.shared
        Notifier.shared.start()
        model.onNudge = { Notifier.shared.post($0) }
        model.start()
        ClassifierWorker.shared.start()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: AppSettings.Keys.firstLaunchDone) {
            defaults.set(true, forKey: AppSettings.Keys.firstLaunchDone)
            WindowManager.shared.showTimeline()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TempoModel.shared.shutdown()
    }
}
