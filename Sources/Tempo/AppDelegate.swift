import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
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
        let model = TempoModel.shared
        Notifier.shared.start()
        model.onNudge = { Notifier.shared.post($0) }
        model.start()
        ClassifierWorker.shared.start()
    }
}
