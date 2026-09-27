# Tempo Stop Tracking and Focus Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Stop tracking button and a focus timer (presets in a hover popover, countdown in the menu bar, Timer done notification, notes window, timeline band) to Tempo's menu bar dropdown.

**Architecture:** Pure logic (timer math, countdown strings, the `focus_sessions` table, the session recap) goes in `TempoCore` with Swift Testing coverage. The app target gets a `FocusController` that owns the running timer and a 1 s ticker, kept apart from `TempoModel` so the timeline is not redrawn every second. Stop tracking reuses the existing pause path with `pausedUntil = .distantFuture`.

**Tech Stack:** Swift 6.1 toolchain (Swift 5 language mode), SwiftUI + AppKit, SQLite3 (system), Swift Testing, UserNotifications.

**Spec:** `docs/superpowers/specs/2026-09-26-tempo-focus-timer-design.md` (read it first; this plan argues from it). Base spec: `docs/superpowers/specs/2026-09-26-tempo-design.md`.

## Global Constraints

- Repo: `~/Desktop/tempo`, branch `tempo-focus-timer` (off `tempo-v1`), local only. All paths below are relative to it.
- macOS 15 minimum, swift-tools-version 6.0, `swiftLanguageModes: [.v5]`.
- No Xcode. Build with `swift build` / `swift test` only. Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). No XCTest.
- No third-party Swift packages.
- Light mode only. Tokens (in `Theme`): bg `#f6f3ec`, panel `#ffffff`, line `#e7e1d5`, ink `#1d1b18`, muted `#6b655b`, chip `#f1ece2`.
- Fonts via `Theme.display` (Bricolage Grotesque), `Theme.ui` (Geist), `Theme.mono` (Geist Mono, times and durations).
- Never use amber or orange attention fills.
- No em dashes or en dashes in any UI copy, notification text, code comments, or docs.
- Stop is not persisted. A running timer is not persisted. Sessions are written when they end.
- Commit after every task with a message ending in:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## File Structure

```
Sources/TempoCore/
  FocusTimer.swift         NEW  FocusTimer value type, presets, custom minutes parsing
  Models.swift             MOD  + FocusSession
  Format.swift             MOD  + countdown, minutesLabel
  Store.swift              MOD  schema v2: focus_sessions table and queries
  Summaries.swift          MOD  + SessionRecap
Sources/Tempo/
  FocusController.swift    NEW  running timer, 1 s ticker, start / end now / discard
  TempoModel.swift         MOD  stop(), isStopped, focusSessions, save / note / recap helpers
  WindowManager.swift      MOD  showFocusNotes(sessionID:), closeFocusNotes()
  TempoApp.swift           MOD  inject FocusController
  Services/Notifier.swift  MOD  timer-done category, action, post, routing
  Views/MenuBarView.swift  MOD  FocusTimerSection in the dropdown, Stop tracking in PauseSection
  Views/MenuBarLabel.swift MOD  Stopped text, clock and countdown
  Views/FocusTimerSection.swift  NEW  start row, preset popover, running row
  Views/FocusNotesView.swift     NEW  notes window content
  Views/Timeline/DayCanvasView.swift   MOD  focus band, FocusBadge, legend
  Views/Timeline/TimelineToolbar.swift MOD  StatusPill "Stopped"
Tests/TempoCoreTests/
  FocusTimerTests.swift    NEW
  FormatTests.swift        MOD
  StoreTests.swift         MOD
  SummariesTests.swift     MOD
docs/hands-on-checklist.md MOD  new section
README.md                  MOD  design link
```

---

### Task 1: FocusTimer, FocusSession, countdown strings

**Files:**
- Create: `Sources/TempoCore/FocusTimer.swift`
- Modify: `Sources/TempoCore/Models.swift` (append after `ClassifyAttempt`)
- Modify: `Sources/TempoCore/Format.swift` (append inside `enum Format`)
- Create: `Tests/TempoCoreTests/FocusTimerTests.swift`
- Modify: `Tests/TempoCoreTests/FormatTests.swift` (append inside `struct FormatTests`)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `public struct FocusTimer: Equatable, Sendable { public let start: Date; public let planned: TimeInterval; public init(start: Date, planned: TimeInterval); public var end: Date; public func remaining(at now: Date) -> TimeInterval; public func isDone(at now: Date) -> Bool; public static let presets: [TimeInterval]; public static let customRange: ClosedRange<Int>; public static func customMinutes(_ text: String) -> Int? }`
  - `public struct FocusSession: Equatable, Identifiable, Sendable { public let id: Int64; public let start: Date; public let end: Date; public let planned: TimeInterval; public var note: String?; public init(id:start:end:planned:note:); public var duration: TimeInterval; public var endedEarly: Bool; public var interval: DateInterval }`
  - `Format.countdown(_ seconds: TimeInterval) -> String`, `Format.minutesLabel(_ seconds: TimeInterval) -> String`

- [ ] **Step 1: Write the failing tests**

Create `Tests/TempoCoreTests/FocusTimerTests.swift`:

```swift
import Foundation
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }

struct FocusTimerTests {
    @Test func remainingCountsDownAndStopsAtZero() {
        let t = FocusTimer(start: d(0), planned: 1500)
        #expect(t.end == d(1500))
        #expect(t.remaining(at: d(0)) == 1500)
        #expect(abs(t.remaining(at: d(47.7)) - 1452.3) < 0.001)
        #expect(t.remaining(at: d(1500)) == 0)
        #expect(t.remaining(at: d(1600)) == 0)
    }

    @Test func doneAtAndAfterTheEnd() {
        let t = FocusTimer(start: d(0), planned: 300)
        #expect(!t.isDone(at: d(299.9)))
        #expect(t.isDone(at: d(300)))
        #expect(t.isDone(at: d(4000)))
    }

    @Test func presetsMatchTheSpec() {
        #expect(FocusTimer.presets == [300, 900, 1800, 3600, 7200])
    }

    @Test func customMinutesAcceptsWholeNumbersOneToSixHundred() {
        #expect(FocusTimer.customMinutes("45") == 45)
        #expect(FocusTimer.customMinutes(" 45 ") == 45)
        #expect(FocusTimer.customMinutes("1") == 1)
        #expect(FocusTimer.customMinutes("600") == 600)
        #expect(FocusTimer.customMinutes("0") == nil)
        #expect(FocusTimer.customMinutes("601") == nil)
        #expect(FocusTimer.customMinutes("4.5") == nil)
        #expect(FocusTimer.customMinutes("abc") == nil)
        #expect(FocusTimer.customMinutes("") == nil)
    }

    @Test func sessionKnowsWhenItEndedEarly() {
        let early = FocusSession(id: 1, start: d(0), end: d(1080), planned: 1500, note: nil)
        #expect(early.duration == 1080)
        #expect(early.endedEarly)
        #expect(early.interval == DateInterval(start: d(0), end: d(1080)))
        let full = FocusSession(id: 2, start: d(0), end: d(1500), planned: 1500, note: "done")
        #expect(!full.endedEarly)
    }
}
```

Append inside `struct FormatTests` in `Tests/TempoCoreTests/FormatTests.swift`:

```swift
    @Test func countdownUnderAnHour() {
        #expect(Format.countdown(1500) == "25:00")
        #expect(Format.countdown(1452.3) == "24:13")
        #expect(Format.countdown(300) == "5:00")
        #expect(Format.countdown(7) == "0:07")
        #expect(Format.countdown(0.2) == "0:01")
        #expect(Format.countdown(0) == "0:00")
        #expect(Format.countdown(-5) == "0:00")
    }

    @Test func countdownWithHours() {
        #expect(Format.countdown(3600) == "1:00:00")
        #expect(Format.countdown(7152) == "1:59:12")
        #expect(Format.countdown(7200) == "2:00:00")
    }

    @Test func countdownIgnoresFloatingPointDust() {
        let start = Date(timeIntervalSinceReferenceDate: 780_000_000.123)
        let t = FocusTimer(start: start, planned: 1500)
        #expect(Format.countdown(t.remaining(at: start)) == "25:00")
    }

    @Test func minutesLabels() {
        #expect(Format.minutesLabel(300) == "5 min")
        #expect(Format.minutesLabel(900) == "15 min")
        #expect(Format.minutesLabel(1800) == "30 min")
        #expect(Format.minutesLabel(2700) == "45 min")
        #expect(Format.minutesLabel(1080) == "18 min")
        #expect(Format.minutesLabel(20) == "1 min")
        #expect(Format.minutesLabel(3600) == "1 hour")
        #expect(Format.minutesLabel(7200) == "2 hours")
        #expect(Format.minutesLabel(36000) == "10 hours")
        #expect(Format.minutesLabel(5400) == "1h 30m")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter "FocusTimerTests|FormatTests" 2>&1 | tail -20`
Expected: build failure, `cannot find 'FocusTimer' in scope` and `type 'Format' has no member 'countdown'`.

- [ ] **Step 3: Implement**

Create `Sources/TempoCore/FocusTimer.swift`:

```swift
import Foundation

/// A running focus countdown (focus timer spec 4.1). Tracking keeps running underneath it.
public struct FocusTimer: Equatable, Sendable {
    public let start: Date
    public let planned: TimeInterval

    public init(start: Date, planned: TimeInterval) {
        self.start = start
        self.planned = planned
    }

    public var end: Date { start.addingTimeInterval(planned) }

    /// Never negative.
    public func remaining(at now: Date) -> TimeInterval { max(0, end.timeIntervalSince(now)) }

    public func isDone(at now: Date) -> Bool { now >= end }

    /// 5 min, 15 min, 30 min, 1 hour, 2 hours.
    public static let presets: [TimeInterval] = [300, 900, 1800, 3600, 7200]

    public static let customRange = 1...600

    /// Whole minutes from the Custom field, 1 to 600, or nil.
    public static func customMinutes(_ text: String) -> Int? {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)), customRange.contains(n) else { return nil }
        return n
    }
}
```

Append to `Sources/TempoCore/Models.swift`:

```swift

/// A finished focus timer, saved when it ends (focus timer spec 4.1).
public struct FocusSession: Equatable, Identifiable, Sendable {
    public let id: Int64
    public let start: Date
    public let end: Date
    public let planned: TimeInterval
    public var note: String?

    public init(id: Int64, start: Date, end: Date, planned: TimeInterval, note: String?) {
        self.id = id
        self.start = start
        self.end = end
        self.planned = planned
        self.note = note
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
    /// Ended with End now at least a second before the planned end.
    public var endedEarly: Bool { duration < planned - 1 }
    public var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }
}
```

Append inside `enum Format` in `Sources/TempoCore/Format.swift`:

```swift

    /// Time left on a timer: "24:13", "5:00", "0:07", "1:59:12". Counts up to the next whole
    /// second, so a new 25 minute timer reads "25:00" and the last second reads "0:01".
    /// The millisecond shave keeps Date arithmetic dust from showing "25:01".
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int((seconds - 0.001).rounded(.up)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? "\(h):" + String(format: "%02d:%02d", m, s) : "\(m):" + String(format: "%02d", s)
    }

    /// A timer length: "5 min", "45 min", "1 hour", "2 hours", "1h 30m". At least "1 min".
    public static func minutesLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 { return minutes == 60 ? "1 hour" : "\(minutes / 60) hours" }
        return duration(TimeInterval(minutes * 60))
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter "FocusTimerTests|FormatTests" 2>&1 | tail -20`
Expected: all FocusTimerTests and FormatTests pass.

Then the full suite: `swift test 2>&1 | tail -5`
Expected: every test passes (68 before this task plus the new ones).

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/FocusTimer.swift Sources/TempoCore/Models.swift Sources/TempoCore/Format.swift Tests/TempoCoreTests/FocusTimerTests.swift Tests/TempoCoreTests/FormatTests.swift
git commit -m "Focus timer core: FocusTimer, FocusSession, countdown strings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Store schema v2 with focus_sessions

**Files:**
- Modify: `Sources/TempoCore/Store.swift` (new `// MARK: Focus sessions` section after `// MARK: Nudges`; `migrate()` gains a `version < 2` block)
- Modify: `Tests/TempoCoreTests/StoreTests.swift`

**Interfaces:**
- Consumes: `FocusSession` (Task 1).
- Produces:
  - `Store.insertFocusSession(start: Date, end: Date, planned: TimeInterval) throws -> Int64` (`@discardableResult`)
  - `Store.setFocusNote(id: Int64, note: String?) throws` (trims whitespace and newlines; empty stores NULL)
  - `Store.focusSession(id: Int64) throws -> FocusSession?`
  - `Store.focusSessions(overlapping: DateInterval) throws -> [FocusSession]` (ordered by start)
  - `meta("schema_version") == "2"`

- [ ] **Step 1: Write the failing tests**

In `Tests/TempoCoreTests/StoreTests.swift`, change the two existing version checks from `"1"` to `"2"`:

- in `migratesFreshDatabase`: `#expect(try store.meta("schema_version") == "2")`
- in `reopensOnDiskDatabase`: `#expect(try reopened.meta("schema_version") == "2")`

Append inside `struct StoreTests`:

```swift
    @Test func focusSessionsInsertNoteAndOverlap() throws {
        let store = try Store(path: ":memory:")
        let a = try store.insertFocusSession(start: d(0), end: d(1500), planned: 1500)
        let b = try store.insertFocusSession(start: d(5000), end: d(5600), planned: 900)
        try store.setFocusNote(id: a, note: "  Shipped the timer \n")
        try store.setFocusNote(id: b, note: "   \n ")
        #expect(try store.focusSession(id: a)
            == FocusSession(id: a, start: d(0), end: d(1500), planned: 1500, note: "Shipped the timer"))
        #expect(try store.focusSession(id: b)?.note == nil)
        #expect(try store.focusSession(id: 999) == nil)
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(1000), end: d(2000))).map(\.id) == [a])
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(0), end: d(9000))).map(\.id) == [a, b])
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(1500), end: d(4999))).isEmpty)
        try store.setFocusNote(id: a, note: nil)
        #expect(try store.focusSession(id: a)?.note == nil)
    }

    /// A database from v1 (no focus_sessions) upgrades in place and keeps its rows.
    @Test func upgradesVersionOneDatabase() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tempo-v1-\(UUID().uuidString).db").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var raw: OpaquePointer?
        #expect(sqlite3_open(path, &raw) == SQLITE_OK)
        let v1 = """
            CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE segments(
              id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL,
              bundle_id TEXT NOT NULL, app_name TEXT NOT NULL, title TEXT, domain TEXT);
            CREATE INDEX segments_start ON segments(start);
            CREATE TABLE rules(
              kind TEXT NOT NULL CHECK(kind IN ('app','domain')), key TEXT NOT NULL,
              category_id TEXT, source TEXT NOT NULL CHECK(source IN ('default','user','claude')),
              updated_at REAL NOT NULL, PRIMARY KEY(kind, key));
            CREATE TABLE nudges(id INTEGER PRIMARY KEY, at REAL NOT NULL,
              kind TEXT NOT NULL CHECK(kind IN ('break','distraction')));
            CREATE TABLE classify_attempts(kind TEXT NOT NULL, key TEXT NOT NULL,
              last_try REAL NOT NULL, failures INTEGER NOT NULL, PRIMARY KEY(kind, key));
            INSERT INTO meta(key, value) VALUES('schema_version', '1');
            INSERT INTO segments(start, end, bundle_id, app_name, title, domain)
              VALUES(1000000, 1000090, 'com.apple.Terminal', 'Terminal', 'zsh', NULL);
            """
        #expect(sqlite3_exec(raw, v1, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(raw)

        let store = try Store(path: path)
        #expect(try store.meta("schema_version") == "2")
        #expect(try store.segments(overlapping: DateInterval(start: d(0), end: d(100)))
            == [Segment(id: 1, start: d(0), end: d(90), snapshot: term)])
        let id = try store.insertFocusSession(start: d(0), end: d(1500), planned: 1500)
        #expect(try store.focusSession(id: id)?.planned == 1500)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter StoreTests 2>&1 | tail -20`
Expected: build failure, `value of type 'Store' has no member 'insertFocusSession'`.

- [ ] **Step 3: Implement**

In `Sources/TempoCore/Store.swift`, add after the `// MARK: Nudges` section (before `// MARK: Classify attempts`):

```swift
    // MARK: Focus sessions

    @discardableResult
    public func insertFocusSession(start: Date, end: Date, planned: TimeInterval) throws -> Int64 {
        try run("INSERT INTO focus_sessions(start, end, planned) VALUES(?, ?, ?)",
                [start.timeIntervalSince1970, end.timeIntervalSince1970, planned])
        return sqlite3_last_insert_rowid(db)
    }

    /// Trims the note; empty or whitespace-only stores no note.
    public func setFocusNote(id: Int64, note: String?) throws {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        try run("UPDATE focus_sessions SET note = ? WHERE id = ?", [value, id])
    }

    public func focusSession(id: Int64) throws -> FocusSession? {
        try query("SELECT id, start, end, planned, note FROM focus_sessions WHERE id = ?", [id],
                  Self.focusRow).first
    }

    public func focusSessions(overlapping interval: DateInterval) throws -> [FocusSession] {
        try query("""
            SELECT id, start, end, planned, note FROM focus_sessions
            WHERE start < ? AND end > ? ORDER BY start
            """, [interval.end.timeIntervalSince1970, interval.start.timeIntervalSince1970],
                  Self.focusRow)
    }

    private static func focusRow(_ s: Statement) -> FocusSession {
        FocusSession(id: s.int(0),
                     start: Date(timeIntervalSince1970: s.double(1)),
                     end: Date(timeIntervalSince1970: s.double(2)),
                     planned: s.double(3),
                     note: s.text(4))
    }
```

In `migrate()`, after the closing brace of the `if version < 1 { ... }` block, add:

```swift
        if version < 2 {
            try exec("""
                BEGIN;
                CREATE TABLE focus_sessions(
                  id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL,
                  planned REAL NOT NULL, note TEXT);
                CREATE INDEX focus_sessions_start ON focus_sessions(start);
                INSERT OR REPLACE INTO meta(key, value) VALUES('schema_version', '2');
                COMMIT;
                """)
        }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter StoreTests 2>&1 | tail -20`
Expected: all StoreTests pass, including `migratesFreshDatabase`, `reopensOnDiskDatabase`, and the two new tests.

Then: `swift test 2>&1 | tail -5`
Expected: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/Store.swift Tests/TempoCoreTests/StoreTests.swift
git commit -m "Store schema v2: focus_sessions table

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: SessionRecap

**Files:**
- Modify: `Sources/TempoCore/Summaries.swift` (append after `DaySummary`)
- Modify: `Tests/TempoCoreTests/SummariesTests.swift` (append inside `struct SummariesTests`)

**Interfaces:**
- Consumes: `DaySummary.make(segments:day:resolver:layout:)`, `DayLayout.empty`, `BlockBuilder.items(for:resolver:)` (internal, same module).
- Produces: `public struct SessionRecap: Equatable, Sendable { public let total: TimeInterval; public let categories: [CategoryTotal]; public let topNames: [String]; public static func make(segments: [Segment], interval: DateInterval, resolver: RuleResolver) -> SessionRecap }`

- [ ] **Step 1: Write the failing tests**

Append inside `struct SummariesTests`:

```swift
    /// 1:30 to 3:00 PM on the mockup Wednesday: Cloudflare docs, Stripe, YouTube, then Figma cut at 3:00.
    @Test func sessionRecapClipsToTheSession() {
        let session = DateInterval(start: F.at(810), end: F.at(900))
        let r = SessionRecap.make(segments: F.wednesday, interval: session, resolver: F.resolver)
        #expect(Int(r.total / 60) == 85)
        #expect(r.categories.map(\.category) == [.research, .distraction, .admin, .design])
        #expect(r.categories.map { Int($0.duration / 60) } == [30, 26, 15, 14])
        #expect(r.topNames == ["developers.cloudflare.com", "youtube.com", "dashboard.stripe.com"])
    }

    @Test func sessionRecapWithNothingTracked() {
        let r = SessionRecap.make(segments: F.wednesday, interval: DateInterval(start: F.at(0), end: F.at(60)),
                                  resolver: F.resolver)
        #expect(r.total == 0)
        #expect(r.categories.isEmpty)
        #expect(r.topNames.isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SummariesTests 2>&1 | tail -20`
Expected: build failure, `cannot find 'SessionRecap' in scope`.

- [ ] **Step 3: Implement**

Append to `Sources/TempoCore/Summaries.swift` after the `DaySummary` struct:

```swift

/// What tracking recorded during one focus session, for the notes window (focus timer spec 3.4).
public struct SessionRecap: Equatable, Sendable {
    public let total: TimeInterval
    /// Non-zero categories, longest first, same order rules as DaySummary.
    public let categories: [CategoryTotal]
    /// The three longest apps or sites.
    public let topNames: [String]

    public static func make(segments: [Segment], interval: DateInterval, resolver: RuleResolver) -> SessionRecap {
        let clipped = segments.compactMap { $0.clipped(to: interval) }
        let summary = DaySummary.make(segments: clipped, day: interval, resolver: resolver, layout: .empty)
        let names = BlockBuilder.items(for: clipped, resolver: resolver).prefix(3).map(\.displayName)
        return SessionRecap(total: summary.total, categories: summary.categories, topNames: Array(names))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SummariesTests 2>&1 | tail -20`
Expected: all SummariesTests pass.

Then: `swift test 2>&1 | tail -5`
Expected: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/Summaries.swift Tests/TempoCoreTests/SummariesTests.swift
git commit -m "SessionRecap: what tracking saw during a focus session

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Stop tracking

**Files:**
- Modify: `Sources/Tempo/TempoModel.swift` (`// MARK: Actions` gains `stop()`; derived state gains `isStopped`; `menuBarText` changes)
- Modify: `Sources/Tempo/Views/MenuBarView.swift` (`PauseSection`)
- Modify: `Sources/Tempo/Views/Timeline/TimelineToolbar.swift` (`StatusPill`)

**Interfaces:**
- Consumes: existing `pausedUntil`, `isPaused`, `resume()`, `monitor.tickNow()`.
- Produces: `TempoModel.stop()`, `TempoModel.isStopped: Bool`.

App target code has no unit tests (the target is an executable with AppKit glue). Verification is `swift build` here and the live checks in Task 9.

- [ ] **Step 1: Model**

In `Sources/Tempo/TempoModel.swift`, add right after `func resume() { ... }`:

```swift

    /// A pause with no end: tracking stays off until Resume. Not saved, so a relaunch tracks again.
    func stop() {
        pausedUntil = .distantFuture
        monitor.tickNow()
    }
```

Replace the `menuBarText` line with:

```swift
    var isStopped: Bool { pausedUntil == .distantFuture }
    var menuBarText: String { isStopped ? "Stopped" : isPaused ? "Paused" : Format.duration(today.total) }
```

(`handleTick` clears `pausedUntil` only when `tickTime >= until`, which never happens for `.distantFuture`, and `isPaused` is true, so the monitor reports `.away`, the open segment closes, and nudges stop exactly as for a timed pause.)

- [ ] **Step 2: Dropdown PauseSection**

In `Sources/Tempo/Views/MenuBarView.swift`, replace the whole `PauseSection` struct with:

```swift
struct PauseSection: View {
    @EnvironmentObject var model: TempoModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Pause tracking")
            if model.isStopped {
                HStack {
                    Text("Tracking stopped").font(Theme.ui(13.5, .semibold))
                    Spacer()
                    SmallButton("Resume") { model.resume() }
                }
            } else if let until = model.pausedUntil {
                HStack {
                    Text("Paused until \(Format.clock(until))").font(Theme.ui(13.5, .semibold))
                    Spacer()
                    SmallButton("Resume") { model.resume() }
                }
            } else {
                HStack(spacing: 6) {
                    SmallButton("30 min", fill: true) { model.pause(for: 1800) }
                    SmallButton("1 hour", fill: true) { model.pause(for: 3600) }
                    SmallButton("Until tomorrow") { model.pause(for: nil) }.fixedSize()
                }
                SmallButton("Stop tracking", fill: true) { model.stop() }
            }
        }
    }
}
```

(`SmallButton`'s `fill: true` means full width, not an ink fill; that matches the spec.)

- [ ] **Step 3: Status pill**

In `Sources/Tempo/Views/Timeline/TimelineToolbar.swift`, inside `StatusPill.body`, replace the first line (`let (text, color): (String, Color) = model.isPaused ? ...`) with:

```swift
        let (text, color): (String, Color) = model.isStopped ? ("Stopped", Theme.muted)
            : model.isPaused ? ("Paused", Theme.muted)
            : model.accessibilityGranted ? ("Tracking", Color(hex: "#2fb35e")) : ("Needs permission", Color(hex: "#c0382f"))
```

- [ ] **Step 4: Build**

Run: `swift build 2>&1 | grep -E "error|warning: unused|Compiling|Build complete" | tail -10`
Expected: `Build complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tempo/TempoModel.swift Sources/Tempo/Views/MenuBarView.swift Sources/Tempo/Views/Timeline/TimelineToolbar.swift
git commit -m "Stop tracking: a pause with no end, until Resume

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Focus sessions in the model, and the notes window

**Files:**
- Modify: `Sources/Tempo/TempoModel.swift`
- Modify: `Sources/Tempo/WindowManager.swift`
- Create: `Sources/Tempo/Views/FocusNotesView.swift`

**Interfaces:**
- Consumes: `Store.insertFocusSession`, `Store.setFocusNote`, `Store.focusSession(id:)`, `Store.focusSessions(overlapping:)` (Task 2); `FocusTimer`, `FocusSession`, `Format.minutesLabel` (Task 1); `SessionRecap.make` (Task 3).
- Produces:
  - `TempoModel.focusSessions: [FocusSession]` (`@Published private(set)`, the shown day's sessions)
  - `TempoModel.saveFocusSession(_ timer: FocusTimer, end: Date) -> FocusSession?`
  - `TempoModel.focusSession(id: Int64) -> FocusSession?`
  - `TempoModel.setFocusNote(id: Int64, note: String)`
  - `TempoModel.recap(for session: FocusSession) -> SessionRecap`
  - `WindowManager.showFocusNotes(sessionID: Int64)`, `WindowManager.closeFocusNotes()`
  - `struct FocusNotesView: View { init(sessionID: Int64) }` (needs `TempoModel` as an environment object)

- [ ] **Step 1: Model**

In `Sources/Tempo/TempoModel.swift`:

Add to the published properties, right after `@Published private(set) var nudgeMarks: [NudgeRecord] = []`:

```swift
    @Published private(set) var focusSessions: [FocusSession] = []
```

In `refresh()`, right after `nudgeMarks = try store.nudges(in: day)`, add:

```swift
            focusSessions = try store.focusSessions(overlapping: day)
```

Add a new section before `// MARK: Actions`:

```swift
    // MARK: Focus sessions

    /// Writes a finished timer. Returns nil (and logs) if the write fails.
    func saveFocusSession(_ timer: FocusTimer, end: Date) -> FocusSession? {
        guard let store else { return nil }
        do {
            let id = try store.insertFocusSession(start: timer.start, end: end, planned: timer.planned)
            refresh()
            return FocusSession(id: id, start: timer.start, end: end, planned: timer.planned, note: nil)
        } catch {
            Log.error("save focus session: \(error)")
            return nil
        }
    }

    func focusSession(id: Int64) -> FocusSession? {
        do { return try store?.focusSession(id: id) } catch {
            Log.error("focus session: \(error)")
            return nil
        }
    }

    func setFocusNote(id: Int64, note: String) {
        do { try store?.setFocusNote(id: id, note: note) } catch { Log.error("focus note: \(error)") }
        refresh()
    }

    /// What tracking recorded during the session, counting the open segment.
    func recap(for session: FocusSession) -> SessionRecap {
        let segs = (try? store?.segments(overlapping: session.interval)) ?? []
        return SessionRecap.make(segments: withLive(segs), interval: session.interval, resolver: resolver)
    }
```

- [ ] **Step 2: WindowManager**

In `Sources/Tempo/WindowManager.swift`, add after `showSettings()`:

```swift

    /// One notes window. Showing it for another session swaps in that session's view.
    func showFocusNotes(sessionID: Int64) {
        let size = NSSize(width: 440, height: 560)
        let root = AnyView(FocusNotesView(sessionID: sessionID).environmentObject(TempoModel.shared))
        if let existing = windows["focus-notes"] {
            existing.contentViewController = NSHostingController(rootView: root)
            existing.setContentSize(size)
        }
        show(id: "focus-notes", title: "Focus notes", size: size,
             minSize: NSSize(width: 400, height: 460), transparentTitlebar: false) { root }
    }

    func closeFocusNotes() {
        windows["focus-notes"]?.close()
    }
```

- [ ] **Step 3: Notes view**

Create `Sources/Tempo/Views/FocusNotesView.swift`:

```swift
import SwiftUI
import TempoCore

/// "What did you get done?" for one focus session (focus timer spec 3.4).
struct FocusNotesView: View {
    @EnvironmentObject var model: TempoModel
    let sessionID: Int64

    @State private var session: FocusSession?
    @State private var recap: SessionRecap?
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        Group {
            if let session {
                content(session)
            } else if loaded {
                missing
            } else {
                Color.clear
            }
        }
        .padding(24)
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
        .onAppear(perform: load)
    }

    private func load() {
        session = model.focusSession(id: sessionID)
        if let session {
            recap = model.recap(for: session)
            text = session.note ?? ""
        }
        loaded = true
    }

    private func subtitle(_ s: FocusSession) -> String {
        let range = "\(Format.clock(s.start)) to \(Format.clock(s.end))"
        return s.endedEarly
            ? "\(range), \(Format.minutesLabel(s.duration)) of \(Format.minutesLabel(s.planned))"
            : "\(range), \(Format.minutesLabel(s.planned))"
    }

    private func content(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What did you get done?").font(Theme.display(26)).kerning(-0.8)
                Text(subtitle(session)).font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Tracked in this session")
                if let recap, let top = recap.categories.first {
                    VStack(spacing: 0) {
                        ForEach(recap.categories, id: \.category) { total in
                            CategoryBarRow(total: total, maxDuration: top.duration, nameWidth: 108).frame(height: 24)
                        }
                    }
                    if !recap.topNames.isEmpty {
                        Text(recap.topNames.joined(separator: ", "))
                            .font(Theme.ui(12.5)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                } else {
                    Text("Nothing tracked in this session.").font(Theme.ui(13)).foregroundStyle(Theme.muted)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Theme.ui(14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if text.isEmpty {
                    Text("What you got done, what's next...")
                        .font(Theme.ui(14)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))

            HStack(spacing: 8) {
                Spacer()
                SmallButton("Skip") { WindowManager.shared.closeFocusNotes() }.fixedSize()
                Button { save(session) } label: {
                    Text("Save").font(Theme.ui(13, .semibold))
                        .padding(.horizontal, 18).frame(height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 8))
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private var missing: some View {
        VStack(spacing: 14) {
            Text("This session could not be found.").font(Theme.ui(14))
            SmallButton("Close") { WindowManager.shared.closeFocusNotes() }.fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func save(_ session: FocusSession) {
        model.setFocusNote(id: session.id, note: text)
        WindowManager.shared.closeFocusNotes()
    }
}
```

- [ ] **Step 4: Build**

Run: `swift build 2>&1 | grep -E "error|Build complete" | tail -10`
Expected: `Build complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tempo/TempoModel.swift Sources/Tempo/WindowManager.swift Sources/Tempo/Views/FocusNotesView.swift
git commit -m "Focus sessions in the model and the notes window

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Timer done notification

**Files:**
- Modify: `Sources/Tempo/Services/Notifier.swift`

**Interfaces:**
- Consumes: `FocusSession`, `Format.minutesLabel`, `Format.clock` (Task 1); `WindowManager.showFocusNotes(sessionID:)` (Task 5).
- Produces: `Notifier.postTimerDone(_ session: FocusSession)`; responses in category `timer-done` open the notes window.

- [ ] **Step 1: Register the category and action**

In `Sources/Tempo/Services/Notifier.swift`, add inside the class, above `private var available`:

```swift
    nonisolated static let timerCategory = "timer-done"
    nonisolated static let writeNotesAction = "write-notes"
```

In `start()`, right after `center.delegate = self`, add:

```swift
        let write = UNNotificationAction(identifier: Self.writeNotesAction,
                                         title: "Write down what you got done", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.timerCategory, actions: [write],
                                   intentIdentifiers: [], options: []),
        ])
```

- [ ] **Step 2: Post**

Add after `post(_ nudge:)`:

```swift

    /// "Timer done", "25 min, 2:10 to 2:35 PM", with a button to write notes (focus timer spec 3.3).
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
```

- [ ] **Step 3: Route the click**

Replace the whole `userNotificationCenter(_:didReceive:withCompletionHandler:)` method with:

```swift
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
```

- [ ] **Step 4: Build**

Run: `swift build 2>&1 | grep -E "error|Build complete" | tail -10`
Expected: `Build complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tempo/Services/Notifier.swift
git commit -m "Timer done notification with a write-notes button

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: FocusController, dropdown timer section, menu bar countdown

**Files:**
- Create: `Sources/Tempo/FocusController.swift`
- Create: `Sources/Tempo/Views/FocusTimerSection.swift`
- Modify: `Sources/Tempo/Views/MenuBarView.swift` (insert `FocusTimerSection()`)
- Modify: `Sources/Tempo/Views/MenuBarLabel.swift`
- Modify: `Sources/Tempo/TempoApp.swift`

**Interfaces:**
- Consumes: `FocusTimer`, `Format.countdown`, `Format.minutesLabel` (Task 1); `TempoModel.saveFocusSession` and `WindowManager.showFocusNotes` (Task 5); `Notifier.postTimerDone` (Task 6); `TempoModel.menuBarText` (Task 4).
- Produces: `@MainActor final class FocusController: ObservableObject` with `static let shared`, `@Published private(set) var timer: FocusTimer?`, `@Published private(set) var now: Date`, `var remaining: TimeInterval`, `func start(seconds: TimeInterval)`, `func endNow()`, `func discard()`.

- [ ] **Step 1: FocusController**

Create `Sources/Tempo/FocusController.swift`:

```swift
import Foundation
import TempoCore

/// The running focus timer (focus timer spec 4.2). Memory only: a quit or crash drops it.
/// Kept apart from TempoModel so the 1 s tick redraws only the timer views, not the timeline.
@MainActor
final class FocusController: ObservableObject {
    static let shared = FocusController()

    @Published private(set) var timer: FocusTimer?
    @Published private(set) var now = Date()
    private var ticker: Timer?

    var remaining: TimeInterval { timer?.remaining(at: now) ?? 0 }

    func start(seconds: TimeInterval) {
        guard timer == nil else { return }
        let n = Date()
        now = n
        timer = FocusTimer(start: n, planned: seconds)
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    /// Saves the session ending now and opens its notes. No notification: Grant is already here.
    func endNow() {
        guard let timer else { return }
        let end = min(Date(), timer.end)
        clear()
        if let session = TempoModel.shared.saveFocusSession(timer, end: end) {
            WindowManager.shared.showFocusNotes(sessionID: session.id)
        }
    }

    func discard() { clear() }

    /// A Mac asleep at the end catches up on wake; the session still ends at the planned end.
    private func tick() {
        now = Date()
        guard let timer, timer.isDone(at: now) else { return }
        clear()
        if let session = TempoModel.shared.saveFocusSession(timer, end: timer.end) {
            Notifier.shared.postTimerDone(session)
        }
    }

    private func clear() {
        ticker?.invalidate()
        ticker = nil
        timer = nil
    }
}
```

- [ ] **Step 2: Dropdown section**

Create `Sources/Tempo/Views/FocusTimerSection.swift`:

```swift
import SwiftUI
import TempoCore

/// The dropdown's focus timer: start one from the preset popover, or watch it count down
/// (focus timer spec 3.1).
struct FocusTimerSection: View {
    @EnvironmentObject var focus: FocusController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Focus timer")
            if let timer = focus.timer {
                RunningTimerRow(timer: timer, remaining: focus.remaining)
            } else {
                StartTimerRow()
            }
        }
    }
}

/// Hovering (or clicking) opens the preset popover beside the row.
struct StartTimerRow: View {
    @EnvironmentObject var focus: FocusController
    @State private var showPresets = false
    @State private var hovering = false

    var body: some View {
        Button { showPresets = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 13, weight: .semibold))
                Text("Start a timer").font(Theme.ui(14, .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(hovering || showPresets ? Theme.chip : Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        .onHover { inside in
            hovering = inside
            guard inside else { return }
            // A short delay, like a native submenu, so passing over the row does not open it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if hovering { showPresets = true }
            }
        }
        .popover(isPresented: $showPresets, arrowEdge: .leading) {
            TimerPresetPopover { seconds in
                showPresets = false
                focus.start(seconds: seconds)
            }
        }
    }
}

struct TimerPresetPopover: View {
    let onStart: (TimeInterval) -> Void
    @State private var custom = ""

    private var customMinutes: Int? { FocusTimer.customMinutes(custom) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: "Start a timer").padding(.horizontal, 10).padding(.bottom, 4)
            ForEach(FocusTimer.presets, id: \.self) { seconds in
                PresetRow(title: Format.minutesLabel(seconds)) { onStart(seconds) }
            }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 6)
            HStack(spacing: 6) {
                Text("Custom").font(Theme.ui(13.5))
                TextField("", text: $custom, prompt: Text("45"))
                    .textFieldStyle(.plain)
                    .font(Theme.mono(13))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40, height: 26)
                    .padding(.horizontal, 6)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
                    .onSubmit(startCustom)
                Text("min").font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                Spacer()
                SmallButton("Start") { startCustom() }
                    .fixedSize()
                    .disabled(customMinutes == nil)
                    .opacity(customMinutes == nil ? 0.45 : 1)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 236)
        .background(Theme.panel)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
    }

    private func startCustom() {
        guard let minutes = customMinutes else { return }
        onStart(TimeInterval(minutes * 60))
    }
}

struct PresetRow: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.ui(13.5, .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Theme.chip : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}

struct RunningTimerRow: View {
    @EnvironmentObject var focus: FocusController
    let timer: FocusTimer
    let remaining: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 14, weight: .semibold))
                Text(Format.countdown(remaining)).font(Theme.mono(18, .semibold)).monospacedDigit()
                    + Text(" left").font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                Spacer()
                SmallButton("End now") { focus.endNow() }.fixedSize()
                SmallButton("Discard") { focus.discard() }.fixedSize()
            }
            Text("\(Format.minutesLabel(timer.planned)), started \(Format.clock(timer.start))")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
        }
    }
}
```

- [ ] **Step 3: Put it in the dropdown**

In `Sources/Tempo/Views/MenuBarView.swift`, inside `MenuBarView.body`, replace the line `            PauseSection()` with:

```swift
            FocusTimerSection()

            PauseSection()
```

- [ ] **Step 4: Menu bar label**

Replace the whole contents of `Sources/Tempo/Views/MenuBarLabel.swift` with:

```swift
import SwiftUI
import TempoCore

struct MenuBarLabel: View {
    @EnvironmentObject var model: TempoModel
    @EnvironmentObject var focus: FocusController
    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuGlyph.image)
            label
        }
    }

    /// One Text with the clock symbol inside it: a MenuBarExtra label is not guaranteed to lay
    /// out more than one image and one text (focus timer spec 3.2).
    private var label: Text {
        guard focus.timer != nil else { return Text(model.menuBarText) }
        return Text("\(model.menuBarText)  \(Image(systemName: "timer")) \(Format.countdown(focus.remaining))")
            .monospacedDigit()
    }
}
```

- [ ] **Step 5: Inject the controller**

In `Sources/Tempo/TempoApp.swift`, add after `@ObservedObject private var model = TempoModel.shared`:

```swift
    @ObservedObject private var focus = FocusController.shared
```

and replace the `MenuBarExtra { ... } label: { ... }` contents so both views get it:

```swift
        MenuBarExtra {
            MenuBarView().environmentObject(model).environmentObject(focus)
        } label: {
            MenuBarLabel().environmentObject(model).environmentObject(focus)
        }
        .menuBarExtraStyle(.window)
```

- [ ] **Step 6: Build**

Run: `swift build 2>&1 | grep -E "error|Build complete" | tail -10`
Expected: `Build complete!` with no errors.

- [ ] **Step 7: Commit**

```bash
git add Sources/Tempo/FocusController.swift Sources/Tempo/Views/FocusTimerSection.swift Sources/Tempo/Views/MenuBarView.swift Sources/Tempo/Views/MenuBarLabel.swift Sources/Tempo/TempoApp.swift
git commit -m "Focus timer: hover presets, countdown row, menu bar clock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Focus band on the timeline

**Files:**
- Modify: `Sources/Tempo/Views/Timeline/DayCanvasView.swift`

**Interfaces:**
- Consumes: `TempoModel.focusSessions`, `WindowManager.showFocusNotes(sessionID:)` (Task 5); `FocusSession`, `Format.minutesLabel` (Task 1).
- Produces: `DayCanvas` gains a `focus: [FocusSession]` parameter (after `nudges`); `struct FocusBadge: View { var size: CGFloat }`.

- [ ] **Step 1: Pass sessions in and swap the legend**

In `DayCanvasView.body`:

- Replace both uses of `nudgeKey` inside the `ViewThatFits` with `legend`.
- Change the `DayCanvas(...)` call to pass the sessions:

```swift
                    DayCanvas(range: model.visibleRange, layout: model.layout, nudges: model.nudgeMarks,
                              focus: model.focusSessions,
                              now: model.isShowingToday ? model.now : nil, selectedID: model.selectedBlockID,
                              calendar: model.calendar) { model.select($0) }
```

Replace the `nudgeKey` property with:

```swift
    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                FocusBadge(size: 18)
                Text("focus timer").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                NudgeBadge(size: 18)
                Text("nudge sent").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
            }
        }
    }
```

- [ ] **Step 2: Draw the band**

In `struct DayCanvas`, add the property after `let nudges: [NudgeRecord]`:

```swift
    let focus: [FocusSession]
```

Inside the `ZStack`, right after the `ForEach(nudges) { ... }` block and before `if let now {`, add:

```swift
                ForEach(focus) { s in
                    let top = y(max(s.start, range.start))
                    let bottom = y(min(s.end, range.end))
                    if bottom > top {
                        FocusBand(height: bottom - top)
                            .help(s.note ?? "Focus timer, \(Format.minutesLabel(s.planned)), no notes yet")
                            .onTapGesture { WindowManager.shared.showFocusNotes(sessionID: s.id) }
                            // Bar centered at x 59.5 (the grid line starts at 58); badge centered on its top.
                            .offset(x: 51.5, y: top - 8)
                            .zIndex(2)
                    }
                }
```

Add these two views after `struct NudgeBadge`:

```swift
/// A focus session: a 3 pt ink bar down the gutter with a clock badge on its top.
struct FocusBand: View {
    let height: CGFloat
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Theme.ink).frame(width: 3, height: height).offset(y: 8)
            FocusBadge(size: 16)
        }
        .frame(width: 16, height: height + 8, alignment: .top)
        .contentShape(Rectangle())
    }
}

struct FocusBadge: View {
    var size: CGFloat = 16
    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundStyle(Theme.panel)
            .frame(width: size, height: size)
            .background(Theme.ink, in: Circle())
            .overlay(Circle().stroke(Theme.panel, lineWidth: 1.5))
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build 2>&1 | grep -E "error|Build complete" | tail -10`
Expected: `Build complete!` with no errors. If any other file constructs `DayCanvas(` (check with `grep -rn "DayCanvas(" Sources`), add `focus: []` there too.

- [ ] **Step 4: Commit**

```bash
git add Sources/Tempo/Views/Timeline/DayCanvasView.swift
git commit -m "Focus sessions as bands on the timeline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Docs, install, live verification

This task is run by the controller session, not a subagent: it installs over the running app and needs Grant for the Accessibility re-grant.

**Files:**
- Modify: `docs/hands-on-checklist.md` (new section at the end)
- Modify: `README.md` (design links)

- [ ] **Step 1: Docs**

Append to `docs/hands-on-checklist.md`:

```markdown

## Stop tracking and focus timer

Spec: `docs/superpowers/specs/2026-09-26-tempo-focus-timer-design.md`.

- [ ] Stop tracking: menu bar reads "Stopped", the row reads "Tracking stopped" with Resume, the toolbar pill says Stopped. No new segments while stopped. Resume tracks again.
- [ ] Stop, then quit and relaunch: Tempo tracks again.
- [ ] Hover "Start a timer": the popover opens beside it after a moment. Passing quickly over the row does not open it. Clicking outside closes it.
- [ ] Each preset starts the right length. Custom: 45 works; 0, 601, 4.5, and letters keep Start disabled; Return starts it.
- [ ] Menu bar shows the total, then the clock and time left, ticking every second without jitter. Over an hour shows h:mm:ss.
- [ ] Stopping or pausing tracking leaves a running timer counting.
- [ ] End now: the notes window opens with the recap and "N min of M". Save stores the note.
- [ ] Discard: nothing appears on the timeline.
- [ ] Let a 5 min timer run out: "Timer done" banner with sound and a "Write down what you got done" button. The button and a banner click both open the notes window.
- [ ] Timeline: the band spans the session with a clock badge. Hover shows the note. Click opens the notes window with the note filled in.
```

In `README.md`, replace the `Design:` and `Plan:` lines with:

```markdown
Design: `docs/superpowers/specs/2026-09-26-tempo-design.md`, plus
`docs/superpowers/specs/2026-09-26-tempo-focus-timer-design.md` (Stop tracking and focus timer)
Plans: `docs/superpowers/plans/2026-09-26-tempo.md`, `docs/superpowers/plans/2026-09-26-tempo-focus-timer.md`
```

Commit:

```bash
git add docs/hands-on-checklist.md README.md
git commit -m "Docs: focus timer checklist and links

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: every test passes.

- [ ] **Step 3: Install**

Run: `scripts/install.sh`
Expected: `installed and started`. With ad-hoc signing, tell Grant to re-grant Accessibility (System Settings, Privacy and Security, Accessibility).

- [ ] **Step 4: Live checks the controller can run**

With computer-use on Tempo: open the dropdown and screenshot it (Focus timer row, Stop tracking button). Hover the row and screenshot the popover. Start a 5 min timer and screenshot the menu bar clock and the running row. Press End now and screenshot the notes window. Check `~/Library/Logs/Tempo.log` for new ERROR lines, and `sqlite3 ~/Library/Application\ Support/Tempo/tempo.db "select * from focus_sessions; select value from meta where key='schema_version';"`.

Known risks to check here, and what to do:
- If the `timer` symbol does not render inside the menu bar label, replace `\(Image(systemName: "timer"))` in `MenuBarLabel` with the character `⏱` and reinstall.
- If opening the popover closes the dropdown, or the Custom field cannot take typing, stop and report it to Grant with a screenshot before changing the design.

- [ ] **Step 5: Report**

Send Grant the screenshots and the remaining checklist items that need him (Accessibility re-grant, the 5 min run-out banner if not already seen).
