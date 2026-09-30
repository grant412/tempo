import AppKit
import TempoCore

/// Blocks sites in Chrome and Safari (site blocking spec 3 and 5.2). Runs whether tracking is
/// on, paused, or stopped. Every second it checks the front tab of a frontmost browser; every
/// fifth second it checks every tab of each running browser.
@MainActor
final class BlockEnforcer: ObservableObject {
    static let shared = BlockEnforcer()

    /// The Distraction window running now, nil outside it. Assigned only when it changes, so
    /// views do not redraw every second.
    @Published private(set) var distractionWindow: DateInterval?
    let adult: AdultSites
    /// False when the bundled list could not be read (Settings shows "List missing").
    let adultListLoaded: Bool

    private let tabs = BrowserTabs()
    private let calendar = Calendar.autoupdatingCurrent
    private var timer: Timer?
    private var ticks = 0
    private var lastRewrite: [BrowserTabs.TabRef: (from: String, at: Date)] = [:]
    private var lastFailureLog: [String: Date] = [:]
    /// A browser whose tab read failed is skipped until this tick, so a hung browser does not
    /// stall the main thread with a 1 s timeout every second.
    private var skipUntilTick: [String: Int] = [:]

    private init() {
        let text = Bundle.main.url(forResource: "oisd-nsfw-small", withExtension: "txt", subdirectory: "Blocking")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let sites = AdultSites(listText: text ?? "")
        adult = sites
        adultListLoaded = sites.count > 0
        if sites.count == 0 { Log.error("blocking: adult list missing, blocking by words only") }
    }

    var isLocked: Bool { distractionWindow != nil }

    func isAdult(_ host: String) -> Bool { adult.contains(host: host) }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    /// Recomputes the window now, after a Settings change or before a rule change.
    func refreshWindow() {
        let w = AppSettings.blockSchedule.window(containing: Date(), calendar: calendar)
        if w != distractionWindow { distractionWindow = w }
    }

    private func tick() {
        let now = Date()
        refreshWindow()
        if !lastRewrite.isEmpty { lastRewrite = lastRewrite.filter { now.timeIntervalSince($0.value.at) < 5 } }
        let policy = BlockPolicy(adult: adult, resolver: TempoModel.shared.resolver, window: distractionWindow)
        let running = BrowserTabs.supported.filter {
            (skipUntilTick[$0] ?? 0) <= ticks
                && !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }
        if ticks % 5 == 0 {
            for id in running.sorted() {
                guard let all = tabs.allTabs(bundleID: id) else {
                    logFailure(id, now: now)
                    skipUntilTick[id] = ticks + 10
                    continue
                }
                for tab in all { enforce(tab, policy: policy, now: now) }
            }
        } else if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                  running.contains(front), let tab = tabs.frontTab(bundleID: front) {
            enforce(tab, policy: policy, now: now)
        }
        ticks += 1
    }

    private func enforce(_ tab: BrowserTabs.Tab, policy: BlockPolicy, now: Date) {
        switch policy.action(for: tab.url) {
        case .allow:
            return
        case .blockAdult:
            if tabs.setURL(blockedPage(["kind": "adult"]), at: tab.ref) {
                Log.info("blocked an adult site")
            } else {
                logFailure(tab.ref.bundleID, now: now)
            }
        case .blockDistraction(let site, let until):
            let page = blockedPage(["kind": "distraction", "site": site, "until": Format.clock(until)])
            if tabs.setURL(page, at: tab.ref) {
                Log.info("blocked \(site)")
            } else {
                logFailure(tab.ref.bundleID, now: now)
            }
        case .rewrite(let url):
            // An engine that strips the parameter would reload forever; retry at most every 5 s.
            if let last = lastRewrite[tab.ref], last.from == tab.url { return }
            lastRewrite[tab.ref] = (tab.url, now)
            if !tabs.setURL(url, at: tab.ref) { logFailure(tab.ref.bundleID, now: now) }
        }
    }

    /// The bundled blocked page with its query, or about:blank in a dev build with no bundle.
    private func blockedPage(_ query: [String: String]) -> String {
        guard let url = Bundle.main.url(forResource: "blocked", withExtension: "html", subdirectory: "Blocking"),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "about:blank" }
        parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return parts.string ?? "about:blank"
    }

    /// A failed tab read or write, logged at most once a minute per browser.
    private func logFailure(_ bundleID: String, now: Date) {
        if let last = lastFailureLog[bundleID], now.timeIntervalSince(last) < 60 { return }
        lastFailureLog[bundleID] = now
        Log.error("blocking: could not read or set tabs in \(bundleID)")
    }
}
