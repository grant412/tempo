import AppKit
import TempoCore

/// Ticks every 5 s and turns the system state into a Presence (spec section 6).
@MainActor
final class ActivityMonitor {
    var onTick: ((Date, Presence) -> Void)?
    var isPaused: () -> Bool = { false }
    var idleThreshold: TimeInterval = 300

    static let ignored: Set<String> = ["com.apple.loginwindow", "com.apple.ScreenSaver.Engine"]
    private let session = SessionObserver()
    private var timer: Timer?
    /// The last tick a display-sleep assertion (a call or playing video) was held. Idle time
    /// counts from here too, so a call with no typing still counts after it ends.
    private var lastAssertionHeld: Date?

    func start() {
        session.onChange = { [weak self] in self?.tickNow() }
        session.start()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickNow() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tickNow()
    }

    func tickNow() {
        let now = Date()
        onTick?(now, presence(at: now))
    }

    func presence(at now: Date) -> Presence {
        if isPaused() || session.isAway { return .away }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier, !Self.ignored.contains(bundleID) else { return .away }
        let idle = IdleReader.secondsSinceInput()
        let assertionHeld = IdleReader.displaySleepPrevented()
        if assertionHeld { lastAssertionHeld = now }
        if idle >= idleThreshold && !assertionHeld {
            return .idle(lastInput: max(now.addingTimeInterval(-idle), lastAssertionHeld ?? .distantPast))
        }
        var title = WindowTitleReader.title(pid: app.processIdentifier)
        var domain: String?
        switch BrowserTabReader.shared.read(bundleID: bundleID) {
        case .incognito?:
            title = nil
        case .tab(let url, let tabTitle)?:
            domain = Domain.normalize(url)
            if let tabTitle, !tabTitle.isEmpty { title = String(tabTitle.prefix(300)) }
            // An adult site is recorded like incognito: no title, no domain (site blocking spec 3.5).
            if let d = domain, BlockEnforcer.shared.isAdult(d) {
                title = nil
                domain = nil
            }
        case nil:
            // A browser whose tab read failed (Automation denied, timeout, error) records no
            // title, so an incognito window's title can never slip in through Accessibility.
            if BrowserTabReader.supported.contains(bundleID) { title = nil }
        }
        return .active(Snapshot(bundleID: bundleID, appName: app.localizedName ?? bundleID,
                                title: title, domain: domain))
    }
}
