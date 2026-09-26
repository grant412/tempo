import AppKit
import Foundation
import TempoCore

@MainActor
final class TempoModel: ObservableObject {
    static let shared = TempoModel()

    struct NeedsCategory: Equatable {
        let key: ItemKey
        let name: String
        let duration: TimeInterval
    }

    @Published private(set) var shownDay = Calendar.current.startOfDay(for: Date())
    @Published private(set) var now = Date()
    @Published private(set) var layout = DayLayout.empty
    @Published private(set) var summary = DaySummary.empty
    @Published private(set) var today = DaySummary.empty
    @Published private(set) var liveBlock: Block?
    @Published private(set) var week: [WeekDay] = []
    @Published private(set) var nudgeMarks: [NudgeRecord] = []
    @Published private(set) var needsCategory: NeedsCategory?
    @Published private(set) var rules: [Rule] = []
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var accessibilityGranted = true
    @Published private(set) var keyRejected = false
    @Published var selectedBlockID: Date?

    let calendar = Calendar.current
    private(set) var store: Store?
    private(set) var resolver = RuleResolver(rules: [])
    private(set) var queue: ClassifierQueue?
    private var builder = SegmentBuilder()
    private var recorder: SegmentRecorder?
    private var nudgeEngine = NudgeEngine()
    private let monitor = ActivityMonitor()
    private var started = false
    var onNudge: ((Nudge) -> Void)?

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        AppSettings.registerDefaults()
        keyRejected = UserDefaults.standard.bool(forKey: AppSettings.Keys.keyRejected)
        openStore()
        guard let store else { return }
        do { try DefaultRules.seed(into: store, at: Date()) } catch { Log.error("seed: \(error)") }
        reloadRules()
        recorder = SegmentRecorder(store: store)
        queue = ClassifierQueue(store: store)
        applySettings()
        accessibilityGranted = AXIsProcessTrusted()
        if !accessibilityGranted { Permissions.promptAccessibility() }
        monitor.isPaused = { [weak self] in self?.isPaused ?? false }
        monitor.onTick = { [weak self] now, presence in self?.handleTick(now: now, presence: presence) }
        monitor.start()
    }

    /// A lock held by another program is retried, then reported with the file left in place.
    /// Only a database that fails for another reason is moved aside (spec 12).
    private func openStore() {
        let dir = AppPaths.dataDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var attempt = 1
        while true {
            do {
                store = try Store(path: AppPaths.database.path)
                return
            } catch {
                Log.error("open store (try \(attempt) of 3): \(error)")
                guard Self.isLockError(error) else { break }
                guard attempt < 3 else {
                    Log.error("open store: still locked, not tracking this session")
                    showAlert("Tempo could not open its database",
                              "Another program has it open, so Tempo is not tracking right now. "
                                  + "Quit that program, then reopen Tempo.")
                    return
                }
                attempt += 1
                Thread.sleep(forTimeInterval: 1)
            }
        }
        let broken = dir.appendingPathComponent("tempo.db.broken-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: AppPaths.database, to: broken)
        store = try? Store(path: AppPaths.database.path)
        showAlert("Tempo started a fresh database",
                  "The old one could not be opened, so it was moved to \(broken.lastPathComponent).")
    }

    /// SQLite reports a held lock as "database is locked" (SQLITE_BUSY) or "... is locked" (SQLITE_LOCKED).
    private static func isLockError(_ error: Error) -> Bool {
        let message: String
        switch error {
        case StoreError.open(let text), StoreError.sql(let text): message = text
        default: message = String(describing: error)
        }
        let lower = message.lowercased()
        return lower.contains("locked") || lower.contains("busy")
    }

    private func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    // MARK: Ticks

    private func handleTick(now tickTime: Date, presence: Presence) {
        let wasToday = isShowingToday
        now = tickTime
        if wasToday && !calendar.isDate(shownDay, inSameDayAs: tickTime) {
            shownDay = calendar.startOfDay(for: tickTime)
            selectedBlockID = nil
        }
        if let until = pausedUntil, tickTime >= until { pausedUntil = nil }
        accessibilityGranted = AXIsProcessTrusted()

        let events = builder.tick(at: tickTime, presence: presence)
        do {
            let closed = try recorder?.apply(events, now: tickTime) ?? []
            for seg in closed { enqueue(seg, now: tickTime) }
        } catch {
            Log.error("record: \(error)")
        }

        var category: CategoryID?
        if case .active(let snapshot) = presence { category = resolver.category(for: snapshot.itemKey) }
        for nudge in nudgeEngine.observe(at: tickTime, presence: presence, category: category) {
            do { try store?.logNudge(nudge.kind, at: nudge.at) } catch { Log.error("nudge: \(error)") }
            onNudge?(nudge)
        }
        refresh()
    }

    private func enqueue(_ seg: Segment, now: Date) {
        let item = ClassifyItem(key: seg.itemKey, appName: seg.snapshot.appName, sampleTitle: seg.snapshot.title)
        do { try queue?.enqueue(item, resolver: resolver, now: now) } catch { Log.error("enqueue: \(error)") }
    }

    /// Queues every uncategorized key seen today (used when an API key is added).
    func enqueueUnknownKeys() {
        guard let store, let day = calendar.dateInterval(of: .day, for: Date()) else { return }
        let segs = (try? store.segments(overlapping: day)) ?? []
        for s in segs where resolver.category(for: s.itemKey) == .uncategorized { enqueue(s, now: Date()) }
    }

    // MARK: Derived state

    func refresh() {
        guard let store,
              let day = calendar.dateInterval(of: .day, for: shownDay),
              let todayInterval = calendar.dateInterval(of: .day, for: now) else { return }
        let weekInterval = WeekSummary.interval(containing: shownDay, calendar: calendar)
        let openEnd = builder.open?.end
        do {
            let weekSegs = withLive(try store.segments(overlapping: weekInterval))
            let daySegs = weekSegs.filter { $0.end > day.start && $0.start < day.end }
            layout = BlockBuilder.build(segments: daySegs, day: day, resolver: resolver, openSegmentEnd: openEnd)
            summary = DaySummary.make(segments: daySegs, day: day, resolver: resolver, layout: layout)
            week = WeekSummary.days(segments: weekSegs, week: weekInterval, calendar: calendar, resolver: resolver)
            if isShowingToday {
                today = summary
                liveBlock = layout.blocks.last(where: \.isLive)
            } else {
                let todaySegs = withLive(try store.segments(overlapping: todayInterval))
                let todayLayout = BlockBuilder.build(segments: todaySegs, day: todayInterval, resolver: resolver,
                                                     openSegmentEnd: openEnd)
                today = DaySummary.make(segments: todaySegs, day: todayInterval, resolver: resolver, layout: todayLayout)
                liveBlock = todayLayout.blocks.last(where: \.isLive)
            }
            nudgeMarks = try store.nudges(in: day)
            needsCategory = computeNeedsCategory(daySegs, day: day)
            if selectedBlockID == nil || !layout.blocks.contains(where: { $0.id == selectedBlockID }) {
                selectedBlockID = (layout.blocks.last(where: \.isLive) ?? summary.longestBlock)?.id
            }
        } catch {
            Log.error("refresh: \(error)")
        }
    }

    /// Stored rows lag the open segment by up to 30 s; show its live end instead.
    private func withLive(_ segs: [Segment]) -> [Segment] {
        guard var open = builder.open else { return segs }
        open.id = recorder?.openID
        var out = segs.filter { $0.id == nil || $0.id != open.id }
        out.append(open)
        return out.sorted { $0.start < $1.start }
    }

    private func computeNeedsCategory(_ segs: [Segment], day: DateInterval) -> NeedsCategory? {
        var totals: [ItemKey: (name: String, duration: TimeInterval)] = [:]
        for s in segs {
            guard let c = s.clipped(to: day), resolver.category(for: c.itemKey) == .uncategorized else { continue }
            let current = totals[c.itemKey] ?? (c.snapshot.displayName, 0)
            totals[c.itemKey] = (current.name, current.duration + c.duration)
        }
        guard let best = totals.max(by: { $0.value.duration < $1.value.duration }),
              best.value.duration >= 60 else { return nil }
        return NeedsCategory(key: best.key, name: best.value.name, duration: best.value.duration)
    }

    var isPaused: Bool { pausedUntil.map { Date() < $0 } ?? false }
    var isShowingToday: Bool { calendar.isDate(shownDay, inSameDayAs: now) }
    var menuBarText: String { isPaused ? "Paused" : Format.duration(today.total) }
    var selectedBlock: Block? { layout.blocks.first { $0.id == selectedBlockID } }

    var dayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        let text = f.string(from: shownDay)
        return isShowingToday ? "Today, " + text : text
    }

    /// The day's three most-used categories, padded with Code, Research, Admin.
    var quickCategories: [CategoryID] {
        var out = summary.categories.map(\.category).filter { $0 != .uncategorized }
        for c in [CategoryID.code, .research, .admin] where !out.contains(c) { out.append(c) }
        return Array(out.prefix(3))
    }

    /// 8 AM to 6 PM, widened to the hour before the first activity and the hour after the last (or now).
    var visibleRange: DateInterval {
        let day = calendar.dateInterval(of: .day, for: shownDay)!
        var startHour = 8
        var endHour = 18
        if let first = summary.firstActivity {
            startHour = min(startHour, max(0, calendar.component(.hour, from: first) - 1))
        }
        let last = isShowingToday ? max(summary.lastActivity ?? now, now) : summary.lastActivity
        if let last { endHour = max(endHour, min(24, calendar.component(.hour, from: last) + 1)) }
        let start = calendar.date(byAdding: .hour, value: startHour, to: day.start)!
        let end = endHour >= 24 ? day.end : calendar.date(byAdding: .hour, value: endHour, to: day.start)!
        return DateInterval(start: start, end: end)
    }

    // MARK: Actions

    func reloadRules() {
        guard let store else { return }
        do {
            rules = try store.allRules()
            resolver = RuleResolver(rules: rules)
        } catch {
            Log.error("rules: \(error)")
        }
    }

    func goToDay(_ date: Date) {
        shownDay = calendar.startOfDay(for: date)
        selectedBlockID = nil
        refresh()
    }

    func shiftDay(_ delta: Int) {
        guard let d = calendar.date(byAdding: .day, value: delta, to: shownDay), d <= now else { return }
        goToDay(d)
    }

    func goToToday() { goToDay(Date()) }

    func select(_ block: Block) { selectedBlockID = block.id }

    func setCategory(_ key: ItemKey, _ category: CategoryID) {
        do { try store?.setUserRule(key, category: category, at: Date()) } catch { Log.error("set rule: \(error)") }
        reloadRules()
        refresh()
    }

    func deleteRule(_ key: ItemKey) {
        do { try store?.deleteRule(key, at: Date()) } catch { Log.error("delete rule: \(error)") }
        reloadRules()
        refresh()
    }

    /// nil pauses until the next local midnight.
    func pause(for seconds: TimeInterval?) {
        let n = Date()
        pausedUntil = seconds.map { n.addingTimeInterval($0) }
            ?? calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: n)!)
        monitor.tickNow()
    }

    func resume() {
        pausedUntil = nil
        monitor.tickNow()
    }

    func applySettings() {
        nudgeEngine.settings = AppSettings.nudgeSettings
        monitor.idleThreshold = AppSettings.idleSeconds
    }

    func setKeyRejected(_ value: Bool) {
        keyRejected = value
        UserDefaults.standard.set(value, forKey: AppSettings.Keys.keyRejected)
    }
}
