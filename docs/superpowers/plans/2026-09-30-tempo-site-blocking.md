# Tempo Site Blocking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tempo blocks adult sites all the time, Distraction sites during one scheduled window (locked while it runs), and forces SafeSearch, in Chrome and Safari, by swapping the tab's URL through AppleScript.

**Architecture:** Pure logic goes in `TempoCore` with Swift Testing coverage: the adult list matcher (`AdultSites`), the SafeSearch rewriter, the weekly window (`BlockSchedule`), the per-tab decision (`BlockPolicy`), and the rule lock (`RuleLock`). The app target gets `BrowserTabs` (AppleScript reads and writes of every tab) and `BlockEnforcer` (a 1 s timer that applies the policy), plus Settings, menu, rules sheet, and inspector changes. A local `blocked.html` ships in the app bundle.

**Tech Stack:** Swift 6.1 toolchain (Swift 5 language mode), SwiftUI + AppKit, NSAppleScript, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-30-tempo-site-blocking-design.md` (read it first; this plan argues from it). Base spec: `docs/superpowers/specs/2026-09-26-tempo-design.md`.

## Global Constraints

- Repo: `~/Desktop/tempo`, branch `tempo-site-blocking` (off `main`). All paths below are relative to it.
- macOS 15 minimum, swift-tools-version 6.0, `swiftLanguageModes: [.v5]`.
- No Xcode. Build with `swift build` / `swift test` only. Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). No XCTest.
- No third-party Swift packages.
- Browsers: Chrome (`com.google.Chrome`) and Safari (`com.apple.Safari`) only.
- Never send an Apple Event to a browser that is not running (a `tell` launches it).
- Adult sites are never written anywhere: not to the segments table, not to the classifier queue, not to the log. Log "blocked an adult site", never the domain.
- Light mode only. Tokens (in `Theme`): bg `#f6f3ec`, panel `#ffffff`, line `#e7e1d5`, ink `#1d1b18`, muted `#6b655b`, chip `#f1ece2`.
- Fonts via `Theme.display` (Bricolage Grotesque), `Theme.ui` (Geist), `Theme.mono` (Geist Mono).
- Never use amber or orange attention fills. Locked states use ink on `Theme.chip`.
- No em dashes or en dashes in any UI copy, code comments, or docs.
- The adult list snapshot `Resources/Blocking/oisd-nsfw-small.txt` is already committed (OISD version 202609301216, 21,192 entries). Do not re-download or edit it.
- Commit after every task with a message ending in:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## File Structure

```
Resources/Blocking/
  oisd-nsfw-small.txt        EXISTS  adult list snapshot (committed with this plan)
  blocked.html               NEW     the blocked page
scripts/build-app.sh         MOD     copies Resources/Blocking into the app
Sources/TempoCore/
  AdultSites.swift           NEW     list parsing and host matching
  SafeSearch.swift           NEW     strict SafeSearch URL rewriting
  BlockSchedule.swift        NEW     the weekly Distraction window
  BlockPolicy.swift          NEW     BlockAction and the per-tab decision
  RuleLock.swift             NEW     refuses rule changes that leave Distraction
Sources/Tempo/
  System/BrowserTabs.swift   NEW     AppleScript: front tab, all tabs, set URL
  BlockEnforcer.swift        NEW     1 s timer, window state, applies BlockPolicy
  AppSettings.swift          MOD     block keys, defaults, blockSchedule
  AppDelegate.swift          MOD     starts BlockEnforcer
  ActivityMonitor.swift      MOD     adult tabs recorded like incognito
  TempoModel.swift           MOD     isLocked, lock guard in setCategory / deleteRule
  Theme.swift                MOD     LockedBadge, DayChip
  Views/Settings/RulesSheet.swift       MOD  lock badge for locked rules
  Views/Timeline/InspectorView.swift    MOD  lock badge for locked items
  Views/Settings/SettingsView.swift     MOD  Blocking section, Permissions copy
  Views/MenuBarView.swift               MOD  "Blocking Distraction until ..." line
Tests/TempoCoreTests/
  AdultSitesTests.swift      NEW
  SafeSearchTests.swift      NEW
  BlockScheduleTests.swift   NEW
  BlockPolicyTests.swift     NEW
  RuleLockTests.swift        NEW
README.md, docs/hands-on-checklist.md   MOD
```

---

### Task 1: AdultSites

**Files:**
- Create: `Sources/TempoCore/AdultSites.swift`
- Test: `Tests/TempoCoreTests/AdultSitesTests.swift`

**Interfaces:**
- Consumes: `Domain.candidates(for:)` and `Domain.isIPv4(_:)` (internal, `Sources/TempoCore/Domain.swift`).
- Produces: `public struct AdultSites: Sendable` with `init(listText: String)`, `var count: Int`, `static let words: [String]`, `func contains(host: String) -> Bool`.

- [ ] **Step 1: Write the failing tests**

`Tests/TempoCoreTests/AdultSitesTests.swift`:

```swift
import Foundation
import Testing
@testable import TempoCore

struct AdultSitesTests {
    static let sample = """
    # Title: sample
    # Entries: 5

    example-adult.com
    WWW.Upper.com
    *.wild.net
    nsfw.reddit.com
    adult
    """

    let sites = AdultSites(listText: sample)

    @Test func parsesEntriesSkippingCommentsAndBlanks() {
        #expect(sites.count == 5)
    }

    @Test func matchesExactHostsAndSubdomains() {
        #expect(sites.contains(host: "example-adult.com"))
        #expect(sites.contains(host: "cdn.example-adult.com"))
        #expect(sites.contains(host: "upper.com"))
        #expect(sites.contains(host: "wild.net"))
        #expect(sites.contains(host: "a.b.wild.net"))
        #expect(sites.contains(host: "EXAMPLE-ADULT.COM"))
    }

    @Test func subdomainEntryDoesNotBlockItsParent() {
        #expect(sites.contains(host: "nsfw.reddit.com"))
        #expect(!sites.contains(host: "reddit.com"))
        #expect(!sites.contains(host: "old.reddit.com"))
    }

    @Test func noSuffixSubstringMatch() {
        #expect(!sites.contains(host: "notexample-adult.com"))
    }

    @Test func oneLabelEntriesBlockOnlyTheTopLevelDomain() {
        #expect(sites.contains(host: "anything.adult"))
        #expect(!sites.contains(host: "adult.example.org"))
    }

    @Test func wordsBlockAnyHostContainingThem() {
        #expect(sites.contains(host: "freeporn.example"))
        #expect(sites.contains(host: "myxxxsite.org"))
        #expect(sites.contains(host: "hentaihaven.io"))
        #expect(!sites.contains(host: "github.com"))
    }

    @Test func localHostsAndAddressesNeverMatch() {
        #expect(!sites.contains(host: "porn.test:3000"))
        #expect(!sites.contains(host: "localhost:5173"))
        #expect(!sites.contains(host: "10.0.0.1"))
    }

    @Test func emptyListStillBlocksWords() {
        let empty = AdultSites(listText: "")
        #expect(empty.count == 0)
        #expect(empty.contains(host: "pornsite.com"))
        #expect(!empty.contains(host: "example-adult.com"))
    }

    @Test func shippedListLoads() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Blocking/oisd-nsfw-small.txt")
        let list = AdultSites(listText: try String(contentsOf: url, encoding: .utf8))
        #expect(list.count == 21192)
        #expect(list.contains(host: "pornhub.com"))
        #expect(list.contains(host: "xvideos.com"))
        for host in ["reddit.com", "x.com", "google.com", "tumblr.com", "imgur.com", "youtube.com", "github.com"] {
            #expect(!list.contains(host: host), "\(host) should stay open")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter AdultSitesTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'AdultSites' in scope".

- [ ] **Step 3: Implement**

`Sources/TempoCore/AdultSites.swift`:

```swift
import Foundation

/// Adult sites: the bundled OISD list, a few words, and the list's one-label entries
/// (site blocking spec 5.1).
public struct AdultSites: Sendable {
    public static let words = ["porn", "xxx", "hentai"]

    private let domains: Set<String>
    private let topLevel: Set<String>

    public var count: Int { domains.count + topLevel.count }

    /// Parses OISD "domains (wildcards)" text: one domain per line, `#` comments. Each entry also
    /// covers its subdomains. A one-label entry (xxx, porn) blocks that whole top-level domain.
    public init(listText: String) {
        var domains = Set<String>()
        var topLevel = Set<String>()
        for raw in listText.split(whereSeparator: \.isNewline) {
            var entry = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if entry.isEmpty || entry.hasPrefix("#") { continue }
            if entry.hasPrefix("*.") { entry.removeFirst(2) }
            if entry.hasPrefix("www.") { entry.removeFirst(4) }
            if entry.isEmpty { continue }
            if entry.contains(".") { domains.insert(entry) } else { topLevel.insert(entry) }
        }
        self.domains = domains
        self.topLevel = topLevel
    }

    /// `host` as `Domain.normalize` returns it. Hosts with a port and IPv4 addresses never match.
    public func contains(host: String) -> Bool {
        let host = host.lowercased()
        if host.contains(":") || Domain.isIPv4(host) { return false }
        if Self.words.contains(where: { host.contains($0) }) { return true }
        if let last = host.split(separator: ".").last, topLevel.contains(String(last)) { return true }
        return Domain.candidates(for: host).contains { domains.contains($0) }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter AdultSitesTests 2>&1 | tail -20`
Expected: all AdultSitesTests pass. Then `swift test 2>&1 | tail -5`: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/AdultSites.swift Tests/TempoCoreTests/AdultSitesTests.swift
git commit -m "AdultSites: bundled OISD list, words, and top-level entries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: SafeSearch

**Files:**
- Create: `Sources/TempoCore/SafeSearch.swift`
- Test: `Tests/TempoCoreTests/SafeSearchTests.swift`

**Interfaces:**
- Produces: `public enum SafeSearch` with `static func enforced(_ urlString: String) -> String?` (nil means leave the tab alone).

- [ ] **Step 1: Write the failing tests**

`Tests/TempoCoreTests/SafeSearchTests.swift`:

```swift
import Testing
@testable import TempoCore

struct SafeSearchTests {
    @Test func googleSearchGetsSafeActive() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=cats") == "https://www.google.com/search?q=cats&safe=active")
        #expect(SafeSearch.enforced("https://google.de/search?q=katzen") == "https://google.de/search?q=katzen&safe=active")
        #expect(SafeSearch.enforced("https://www.google.co.uk/search?q=a") == "https://www.google.co.uk/search?q=a&safe=active")
        #expect(SafeSearch.enforced("https://www.google.com.au/search?q=a") == "https://www.google.com.au/search?q=a&safe=active")
    }

    @Test func googleImageSearch() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=cats&udm=2") == "https://www.google.com/search?q=cats&udm=2&safe=active")
    }

    @Test func replacesAnotherValue() {
        #expect(SafeSearch.enforced("https://www.google.com/search?safe=off&q=a") == "https://www.google.com/search?q=a&safe=active")
        #expect(SafeSearch.enforced("https://www.bing.com/videos/search?q=a&adlt=off") == "https://www.bing.com/videos/search?q=a&adlt=strict")
    }

    @Test func alreadyStrictGivesNil() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=a&safe=active") == nil)
        #expect(SafeSearch.enforced("https://www.bing.com/search?q=a&adlt=strict") == nil)
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=a&kp=1") == nil)
    }

    @Test func keepsOtherParametersEncodedAsTheyWere() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=red+cats%20now&oq=red") == "https://www.google.com/search?q=red+cats%20now&oq=red&safe=active")
    }

    @Test func onlyGoogleSearchPathsOnGoogleHosts() {
        #expect(SafeSearch.enforced("https://www.google.com/") == nil)
        #expect(SafeSearch.enforced("https://www.google.com/maps/search/pizza") == nil)
        #expect(SafeSearch.enforced("https://mail.google.com/search?q=a") == nil)
        #expect(SafeSearch.enforced("https://google.evil.com/search?q=a") == nil)
    }

    @Test func bingSearchImagesAndVideos() {
        #expect(SafeSearch.enforced("https://www.bing.com/search?q=a") == "https://www.bing.com/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://www.bing.com/images/search?q=a") == "https://www.bing.com/images/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://cn.bing.com/search?q=a") == "https://cn.bing.com/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://www.bing.com/maps?q=a") == nil)
    }

    @Test func duckDuckGoNeedsAQuery() {
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=a&ia=images") == "https://duckduckgo.com/?q=a&ia=images&kp=1")
        #expect(SafeSearch.enforced("https://html.duckduckgo.com/html/?q=a") == "https://html.duckduckgo.com/html/?q=a&kp=1")
        #expect(SafeSearch.enforced("https://duckduckgo.com/") == nil)
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=") == nil)
    }

    @Test func otherURLsGiveNil() {
        #expect(SafeSearch.enforced("https://github.com/search?q=a") == nil)
        #expect(SafeSearch.enforced("file:///tmp/a.html?q=a") == nil)
        #expect(SafeSearch.enforced("not a url") == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SafeSearchTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'SafeSearch' in scope".

- [ ] **Step 3: Implement**

`Sources/TempoCore/SafeSearch.swift`:

```swift
import Foundation

/// Forces strict SafeSearch on Google, Bing, and DuckDuckGo searches (site blocking spec 5.1).
public enum SafeSearch {
    /// The URL with the engine's strict parameter set, or nil when it is not a search on these
    /// engines or already has it. Every other parameter keeps its exact encoding.
    public static func enforced(_ urlString: String) -> String? {
        guard var parts = URLComponents(string: urlString),
              let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var host = parts.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        var items = parts.percentEncodedQueryItems ?? []
        let param: (name: String, value: String)
        if isGoogle(host), parts.path == "/search" {
            param = ("safe", "active")
        } else if host == "bing.com" || host.hasSuffix(".bing.com"),
                  ["/search", "/images/search", "/videos/search"].contains(parts.path) {
            param = ("adlt", "strict")
        } else if ["duckduckgo.com", "html.duckduckgo.com", "lite.duckduckgo.com"].contains(host),
                  items.contains(where: { $0.name == "q" && !($0.value ?? "").isEmpty }) {
            param = ("kp", "1")
        } else {
            return nil
        }
        let existing = items.filter { $0.name == param.name }
        if existing.count == 1, existing[0].value == param.value { return nil }
        items.removeAll { $0.name == param.name }
        items.append(URLQueryItem(name: param.name, value: param.value))
        parts.percentEncodedQueryItems = items
        return parts.string
    }

    /// google.<tld>, google.co.<cc>, or google.com.<cc>.
    static func isGoogle(_ host: String) -> Bool {
        let labels = host.split(separator: ".")
        guard labels.first == "google" else { return false }
        switch labels.count {
        case 2: return true
        case 3: return labels[1] == "co" || labels[1] == "com"
        default: return false
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SafeSearchTests 2>&1 | tail -20`
Expected: all SafeSearchTests pass. If `keepsOtherParametersEncodedAsTheyWere` fails, the query was re-encoded: make sure only `percentEncodedQueryItems` is read and written (never `queryItems`). Then `swift test 2>&1 | tail -5`: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/SafeSearch.swift Tests/TempoCoreTests/SafeSearchTests.swift
git commit -m "SafeSearch: strict parameter on Google, Bing, and DuckDuckGo searches

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: BlockSchedule

**Files:**
- Create: `Sources/TempoCore/BlockSchedule.swift`
- Test: `Tests/TempoCoreTests/BlockScheduleTests.swift`

**Interfaces:**
- Consumes: `Fixtures.calendar` (America/New_York, `Tests/TempoCoreTests/Fixtures.swift`).
- Produces: `public struct BlockSchedule: Equatable, Sendable` with `init(enabled:weekdays:startMinute:endMinute:)`, `var enabled: Bool`, `var weekdays: Set<Int>` (1 is Sunday), `var startMinute: Int`, `var endMinute: Int`, `var runsPastMidnight: Bool`, `func window(containing: Date, calendar: Calendar) -> DateInterval?`, `static let workweekMask: Int` (62), `static func weekdays(mask: Int) -> Set<Int>`, `static func mask(weekdays: Set<Int>) -> Int`.

- [ ] **Step 1: Write the failing tests**

`Tests/TempoCoreTests/BlockScheduleTests.swift`:

```swift
import Foundation
import Testing
@testable import TempoCore

/// 2026-09-23 is a Wednesday, 09-25 a Friday, 09-26 a Saturday. 2026-11-01 is the Sunday US
/// clocks fall back.
struct BlockScheduleTests {
    let cal = Fixtures.calendar
    let workdays = BlockSchedule(enabled: true, weekdays: [2, 3, 4, 5, 6], startMinute: 540, endMinute: 1020)

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func disabledHasNoWindow() {
        var s = workdays
        s.enabled = false
        #expect(s.window(containing: date(23, 10), calendar: cal) == nil)
    }

    @Test func insideAWorkday() {
        #expect(workdays.window(containing: date(23, 10), calendar: cal) == DateInterval(start: date(23, 9), end: date(23, 17)))
    }

    @Test func startInclusiveEndExclusive() {
        #expect(workdays.window(containing: date(23, 9), calendar: cal) != nil)
        #expect(workdays.window(containing: date(23, 8, 59), calendar: cal) == nil)
        #expect(workdays.window(containing: date(23, 17), calendar: cal) == nil)
    }

    @Test func skipsUnselectedDays() {
        #expect(workdays.window(containing: date(26, 10), calendar: cal) == nil)
    }

    @Test func overnightWindowBelongsToItsStartDay() {
        let fridayNight = BlockSchedule(enabled: true, weekdays: [6], startMinute: 21 * 60, endMinute: 60)
        #expect(fridayNight.runsPastMidnight)
        #expect(fridayNight.window(containing: date(26, 0, 30), calendar: cal) == DateInterval(start: date(25, 21), end: date(26, 1)))
        #expect(fridayNight.window(containing: date(25, 22), calendar: cal) != nil)
        #expect(fridayNight.window(containing: date(26, 1), calendar: cal) == nil)
        let saturdayNight = BlockSchedule(enabled: true, weekdays: [7], startMinute: 21 * 60, endMinute: 60)
        #expect(saturdayNight.window(containing: date(26, 0, 30), calendar: cal) == nil)
    }

    @Test func equalTimesRunAFullDay() {
        let saturday = BlockSchedule(enabled: true, weekdays: [7], startMinute: 0, endMinute: 0)
        #expect(saturday.runsPastMidnight)
        #expect(saturday.window(containing: date(26, 12), calendar: cal) == DateInterval(start: date(26, 0), end: date(27, 0)))
        #expect(saturday.window(containing: date(25, 23, 59), calendar: cal) == nil)
    }

    @Test func dstDayKeepsWallClockTimes() {
        let sundayMorning = BlockSchedule(enabled: true, weekdays: [1], startMinute: 0, endMinute: 720)
        let w = sundayMorning.window(containing: date(1, 11, month: 11), calendar: cal)
        #expect(w == DateInterval(start: date(1, 0, month: 11), end: date(1, 12, month: 11)))
        #expect(w?.duration == TimeInterval(13 * 3600))
    }

    @Test func weekdayMaskRoundTrips() {
        #expect(BlockSchedule.weekdays(mask: BlockSchedule.workweekMask) == [2, 3, 4, 5, 6])
        #expect(BlockSchedule.mask(weekdays: [2, 3, 4, 5, 6]) == 62)
        #expect(BlockSchedule.weekdays(mask: 0) == [])
        #expect(BlockSchedule.mask(weekdays: [1, 7, 9]) == 0b1000001)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter BlockScheduleTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'BlockSchedule' in scope".

- [ ] **Step 3: Implement**

`Sources/TempoCore/BlockSchedule.swift`:

```swift
import Foundation

/// The Distraction block's weekly window (site blocking spec 5.1).
public struct BlockSchedule: Equatable, Sendable {
    public var enabled: Bool
    /// Calendar weekday numbers: 1 is Sunday, 7 is Saturday.
    public var weekdays: Set<Int>
    /// Minutes after midnight, 0 to 1439.
    public var startMinute: Int
    public var endMinute: Int

    public init(enabled: Bool, weekdays: Set<Int>, startMinute: Int, endMinute: Int) {
        self.enabled = enabled
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Monday to Friday. Settings store weekdays as a mask with bit (weekday - 1).
    public static let workweekMask = 0b0111110

    public static func weekdays(mask: Int) -> Set<Int> {
        Set((1...7).filter { mask & (1 << ($0 - 1)) != 0 })
    }

    public static func mask(weekdays: Set<Int>) -> Int {
        weekdays.filter { (1...7).contains($0) }.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    /// End at or before start: the window ends the next day. Equal times make a full 24 hours.
    public var runsPastMidnight: Bool { endMinute <= startMinute }

    /// The window containing `date`, or nil. A window belongs to the day it starts on, so the
    /// one that started yesterday is checked too. Start is inclusive, end exclusive.
    public func window(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard enabled else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let window = window(startingOn: day, calendar: calendar),
                  window.start <= date, date < window.end else { continue }
            return window
        }
        return nil
    }

    private func window(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        let endDay: Date? = runsPastMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day
        guard let endDay,
              let start = Self.time(startMinute, on: day, calendar: calendar),
              let end = Self.time(endMinute, on: endDay, calendar: calendar),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Wall-clock time on that day, so DST days keep the chosen times.
    private static func time(_ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        var c = calendar.dateComponents([.year, .month, .day], from: day)
        c.hour = minute / 60
        c.minute = minute % 60
        return calendar.date(from: c)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter BlockScheduleTests 2>&1 | tail -20`
Expected: all BlockScheduleTests pass. Then `swift test 2>&1 | tail -5`: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/BlockSchedule.swift Tests/TempoCoreTests/BlockScheduleTests.swift
git commit -m "BlockSchedule: the weekly Distraction window, overnight and DST aware

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: BlockPolicy

**Files:**
- Create: `Sources/TempoCore/BlockPolicy.swift`
- Test: `Tests/TempoCoreTests/BlockPolicyTests.swift`

**Interfaces:**
- Consumes: `AdultSites` (Task 1), `SafeSearch.enforced(_:)` (Task 2), `RuleResolver.category(for:)`, `Domain.normalize(_:)`, `Fixtures.resolver`, `Fixtures.at(_:)`.
- Produces: `public enum BlockAction: Equatable, Sendable { case allow, blockAdult, blockDistraction(site: String, until: Date), rewrite(String) }` and `public struct BlockPolicy: Sendable` with `init(adult: AdultSites, resolver: RuleResolver, window: DateInterval?)` and `func action(for url: String) -> BlockAction`.

- [ ] **Step 1: Write the failing tests**

`Tests/TempoCoreTests/BlockPolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import TempoCore

struct BlockPolicyTests {
    let adult = AdultSites(listText: "adultsite.com\n")
    let window = DateInterval(start: Fixtures.at(540), end: Fixtures.at(1020))

    func policy(inWindow: Bool, resolver: RuleResolver = Fixtures.resolver) -> BlockPolicy {
        BlockPolicy(adult: adult, resolver: resolver, window: inWindow ? window : nil)
    }

    @Test func adultIsBlockedInsideAndOutsideTheWindow() {
        #expect(policy(inWindow: false).action(for: "https://adultsite.com/x") == .blockAdult)
        #expect(policy(inWindow: true).action(for: "https://www.adultsite.com/") == .blockAdult)
    }

    @Test func adultWinsOverDistraction() {
        let rules = DefaultRules.asRules + [Rule(key: ItemKey(kind: .domain, key: "adultsite.com"),
                                                 category: .distraction, source: .user, updatedAt: .distantPast)]
        #expect(policy(inWindow: true, resolver: RuleResolver(rules: rules)).action(for: "https://adultsite.com/") == .blockAdult)
    }

    @Test func distractionOnlyInsideTheWindow() {
        #expect(policy(inWindow: true).action(for: "https://www.youtube.com/watch?v=1")
                == .blockDistraction(site: "youtube.com", until: window.end))
        #expect(policy(inWindow: false).action(for: "https://www.youtube.com/watch?v=1") == .allow)
    }

    @Test func subdomainIsBlockedByItsParentsRule() {
        #expect(policy(inWindow: true).action(for: "https://m.youtube.com/")
                == .blockDistraction(site: "m.youtube.com", until: window.end))
    }

    @Test func otherCategoriesAndUnsortedSitesAreAllowed() {
        #expect(policy(inWindow: true).action(for: "https://github.com/") == .allow)
        #expect(policy(inWindow: true).action(for: "https://unsorted-site.example/") == .allow)
    }

    @Test func safeSearchRewriteInsideAndOutsideTheWindow() {
        let expected = BlockAction.rewrite("https://www.google.com/search?q=a&safe=active")
        #expect(policy(inWindow: false).action(for: "https://www.google.com/search?q=a") == expected)
        #expect(policy(inWindow: true).action(for: "https://www.google.com/search?q=a") == expected)
    }

    @Test func nonWebURLsAreAllowed() {
        let page = "file:///Applications/Tempo.app/Contents/Resources/Blocking/blocked.html?kind=adult"
        #expect(policy(inWindow: true).action(for: page) == .allow)
        #expect(policy(inWindow: true).action(for: "chrome://newtab/") == .allow)
        #expect(policy(inWindow: true).action(for: "about:blank") == .allow)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter BlockPolicyTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'BlockPolicy' in scope".

- [ ] **Step 3: Implement**

`Sources/TempoCore/BlockPolicy.swift`:

```swift
import Foundation

public enum BlockAction: Equatable, Sendable {
    case allow
    case blockAdult
    case blockDistraction(site: String, until: Date)
    /// Load this URL instead (SafeSearch).
    case rewrite(String)
}

/// Decides what happens to one tab (site blocking spec 3.1): adult, then Distraction inside the
/// window, then SafeSearch.
public struct BlockPolicy: Sendable {
    public let adult: AdultSites
    public let resolver: RuleResolver
    /// The Distraction window running now, nil outside it.
    public let window: DateInterval?

    public init(adult: AdultSites, resolver: RuleResolver, window: DateInterval?) {
        self.adult = adult
        self.resolver = resolver
        self.window = window
    }

    public func action(for url: String) -> BlockAction {
        guard let host = Domain.normalize(url) else { return .allow }
        if adult.contains(host: host) { return .blockAdult }
        if let window, resolver.category(for: ItemKey(kind: .domain, key: host)) == .distraction {
            return .blockDistraction(site: host, until: window.end)
        }
        if let rewritten = SafeSearch.enforced(url) { return .rewrite(rewritten) }
        return .allow
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter BlockPolicyTests 2>&1 | tail -20`
Expected: all BlockPolicyTests pass. Then `swift test 2>&1 | tail -5`: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/BlockPolicy.swift Tests/TempoCoreTests/BlockPolicyTests.swift
git commit -m "BlockPolicy: adult, then Distraction in the window, then SafeSearch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: RuleLock

**Files:**
- Create: `Sources/TempoCore/RuleLock.swift`
- Test: `Tests/TempoCoreTests/RuleLockTests.swift`

**Interfaces:**
- Consumes: `RuleResolver`, `Rule`, `ItemKey`, `DefaultRules.asRules`.
- Produces: `public enum RuleLock` with `static func allows(_ key: ItemKey, newCategory: CategoryID?, rules: [Rule]) -> Bool` (`newCategory` nil means delete).

- [ ] **Step 1: Write the failing tests**

`Tests/TempoCoreTests/RuleLockTests.swift`:

```swift
import Foundation
import Testing
@testable import TempoCore

struct RuleLockTests {
    let rules = DefaultRules.asRules
    func domain(_ host: String) -> ItemKey { ItemKey(kind: .domain, key: host) }

    @Test func movingADistractionSiteOutIsRefused() {
        #expect(!RuleLock.allows(domain("youtube.com"), newCategory: .research, rules: rules))
    }

    @Test func deletingADistractionRuleIsRefused() {
        #expect(!RuleLock.allows(domain("youtube.com"), newCategory: nil, rules: rules))
    }

    @Test func splittingASubdomainOutIsRefused() {
        #expect(!RuleLock.allows(domain("music.youtube.com"), newCategory: .research, rules: rules))
    }

    @Test func movingASiteIntoDistractionIsAllowed() {
        #expect(RuleLock.allows(domain("github.com"), newCategory: .distraction, rules: rules))
        #expect(RuleLock.allows(domain("brand-new.example"), newCategory: .distraction, rules: rules))
        #expect(RuleLock.allows(domain("youtube.com"), newCategory: .distraction, rules: rules))
    }

    @Test func otherSitesAreNeverLocked() {
        #expect(RuleLock.allows(domain("github.com"), newCategory: .research, rules: rules))
        #expect(RuleLock.allows(domain("github.com"), newCategory: nil, rules: rules))
    }

    @Test func appRulesAreNeverLocked() {
        #expect(RuleLock.allows(ItemKey(kind: .app, key: "com.spotify.client"), newCategory: .code, rules: rules))
        #expect(RuleLock.allows(ItemKey(kind: .app, key: "com.spotify.client"), newCategory: nil, rules: rules))
    }

    @Test func deletingASubdomainRuleUnderADistractionParentIsAllowed() {
        let withSub = rules + [Rule(key: domain("m.youtube.com"), category: .distraction, source: .user, updatedAt: .distantPast)]
        #expect(RuleLock.allows(domain("m.youtube.com"), newCategory: nil, rules: withSub))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RuleLockTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'RuleLock' in scope".

- [ ] **Step 3: Implement**

`Sources/TempoCore/RuleLock.swift`:

```swift
import Foundation

/// While a Distraction window runs, refuses rule changes that would take a domain out of
/// Distraction (site blocking spec 3.4). Only consulted while a window runs.
public enum RuleLock {
    /// `newCategory` nil means the rule is being deleted. App rules are never locked.
    public static func allows(_ key: ItemKey, newCategory: CategoryID?, rules: [Rule]) -> Bool {
        guard key.kind == .domain else { return true }
        guard RuleResolver(rules: rules).category(for: key) == .distraction else { return true }
        var after = rules.filter { $0.key != key }
        after.append(Rule(key: key, category: newCategory, source: .user, updatedAt: Date()))
        return RuleResolver(rules: after).category(for: key) == .distraction
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter RuleLockTests 2>&1 | tail -20`
Expected: all RuleLockTests pass. Then `swift test 2>&1 | tail -5`: every test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoCore/RuleLock.swift Tests/TempoCoreTests/RuleLockTests.swift
git commit -m "RuleLock: refuse rule changes that take a site out of Distraction

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Blocked page, build copy, and BrowserTabs

**Files:**
- Create: `Resources/Blocking/blocked.html`
- Modify: `scripts/build-app.sh` (the `mkdir -p` line and a new copy line after the fonts copy)
- Create: `Sources/Tempo/System/BrowserTabs.swift`

**Interfaces:**
- Produces: the page at `Contents/Resources/Blocking/blocked.html` taking `kind` (`adult` or `distraction`), `site`, `until` query parameters. `@MainActor final class BrowserTabs` with `struct TabRef: Hashable { bundleID: String; window: Int; tab: Int }`, `struct Tab { ref: TabRef; url: String }`, `static let chrome`, `static let safari`, `static let supported: Set<String>`, `func frontTab(bundleID: String) -> Tab?`, `func allTabs(bundleID: String) -> [Tab]?` (nil means the read failed), `@discardableResult func setURL(_ url: String, at ref: TabRef) -> Bool`.

No unit tests: the page is checked with a headless Chrome screenshot and the AppleScript code by compiling and by the hands-on checklist (Task 10).

- [ ] **Step 1: Write the blocked page**

`Resources/Blocking/blocked.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Blocked</title>
<style>
  :root { --bg: #f6f3ec; --panel: #ffffff; --line: #e7e1d5; --ink: #1d1b18; --muted: #6b655b; }
  * { box-sizing: border-box; }
  html, body { margin: 0; height: 100%; }
  body {
    background: var(--bg); color: var(--ink);
    font-family: -apple-system, system-ui, sans-serif;
    display: flex; align-items: center; justify-content: center; padding: 24px;
  }
  .card {
    background: var(--panel); border: 1px solid var(--line); border-radius: 16px;
    padding: 36px 40px; max-width: 540px; width: 100%;
  }
  .eyebrow {
    font: 600 11px/1 ui-monospace, "SF Mono", Menlo, monospace; letter-spacing: 0.1em;
    text-transform: uppercase; color: var(--muted); margin: 0 0 14px;
  }
  h1 { font-size: 30px; line-height: 1.2; font-weight: 800; letter-spacing: -0.02em; margin: 0; overflow-wrap: anywhere; }
</style>
</head>
<body>
<main class="card">
  <p class="eyebrow" id="eyebrow">Tempo</p>
  <h1 id="headline">This site is blocked.</h1>
</main>
<script>
  const q = new URLSearchParams(location.search);
  if (q.get("kind") === "distraction") {
    const site = q.get("site") || "This site";
    const until = q.get("until");
    document.getElementById("eyebrow").textContent = "Distraction block";
    document.getElementById("headline").textContent =
      until ? site + " is blocked until " + until + "." : site + " is blocked.";
  }
</script>
</body>
</html>
```

- [ ] **Step 2: Check the page renders**

Run:

```bash
mkdir -p build/blocked-check
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$PWD/build/blocked-check/profile" \
  --window-size=900,560 --screenshot="$PWD/build/blocked-check/distraction.png" \
  "file://$PWD/Resources/Blocking/blocked.html?kind=distraction&site=youtube.com&until=5%3A00%20PM"
"$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$PWD/build/blocked-check/profile" \
  --window-size=900,560 --screenshot="$PWD/build/blocked-check/adult.png" \
  "file://$PWD/Resources/Blocking/blocked.html?kind=adult"
```

Open both PNGs with the Read tool. Expected: a white card on the paper background. `distraction.png` reads "DISTRACTION BLOCK" and "youtube.com is blocked until 5:00 PM." `adult.png` reads "TEMPO" and "This site is blocked." with no site name. (`build/` is gitignored.)

- [ ] **Step 3: Copy the Blocking folder into the app**

In `scripts/build-app.sh`, change

```zsh
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
```

to

```zsh
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" "$APP/Contents/Resources/Blocking"
```

and add this line right after the `cp Resources/Fonts/*.ttf ...` line:

```zsh
cp Resources/Blocking/blocked.html Resources/Blocking/oisd-nsfw-small.txt "$APP/Contents/Resources/Blocking/"
```

- [ ] **Step 4: Write BrowserTabs**

`Sources/Tempo/System/BrowserTabs.swift`:

```swift
import AppKit

/// Reads and sets tab URLs in Chrome and Safari for site blocking (site blocking spec 5.2).
/// Unlike the tracker's `BrowserTabReader` it sees every tab, incognito and private ones
/// included; nothing read here is stored. Callers check that the browser is running first,
/// because a `tell` would launch it.
@MainActor
final class BrowserTabs {
    struct TabRef: Hashable {
        let bundleID: String
        /// The browser's window id.
        let window: Int
        /// 1-based tab index in that window. Read and write happen in the same tick.
        let tab: Int
    }

    struct Tab {
        let ref: TabRef
        let url: String
    }

    static let chrome = "com.google.Chrome"
    static let safari = "com.apple.Safari"
    static let supported: Set<String> = [chrome, safari]

    /// Each script returns one line per tab: window id, tab index, URL, joined by a tab
    /// character. `sep` is set outside the `tell` because `tab` names a tab object inside it.
    private static let frontSources: [String: String] = [
        chrome: """
        set sep to character id 9
        with timeout of 1 second
          tell application id "com.google.Chrome"
            if (count of windows) is 0 then return ""
            set w to front window
            return ((id of w) as text) & sep & ((active tab index of w) as text) & sep & (URL of active tab of w)
          end tell
        end timeout
        """,
        safari: """
        set sep to character id 9
        with timeout of 1 second
          tell application id "com.apple.Safari"
            if (count of windows) is 0 then return ""
            set w to front window
            set t to current tab of w
            set u to URL of t
            if u is missing value then return ""
            return ((id of w) as text) & sep & ((index of t) as text) & sep & u
          end tell
        end timeout
        """,
    ]

    /// Two Apple Events per window (URLs in bulk), not one per tab. A window that errors is skipped.
    private static let allSources: [String: String] = [
        chrome: """
        set sep to character id 9
        set out to ""
        with timeout of 1 second
          tell application id "com.google.Chrome"
            repeat with w in windows
              try
                set wid to id of w
                set urls to URL of every tab of w
                repeat with i from 1 to count of urls
                  set out to out & (wid as text) & sep & (i as text) & sep & (item i of urls) & linefeed
                end repeat
              end try
            end repeat
          end tell
        end timeout
        return out
        """,
        safari: """
        set sep to character id 9
        set out to ""
        with timeout of 1 second
          tell application id "com.apple.Safari"
            repeat with w in windows
              try
                set wid to id of w
                set urls to URL of every tab of w
                repeat with i from 1 to count of urls
                  set u to item i of urls
                  if u is not missing value then
                    set out to out & (wid as text) & sep & (i as text) & sep & u & linefeed
                  end if
                end repeat
              end try
            end repeat
          end tell
        end timeout
        return out
        """,
    ]

    private var compiled: [String: NSAppleScript] = [:]

    func frontTab(bundleID: String) -> Tab? {
        guard let source = Self.frontSources[bundleID],
              let text = run("front " + bundleID, source) else { return nil }
        return parse(text, bundleID: bundleID).first
    }

    /// nil when the read failed (Automation denied, timeout); empty when there are no tabs.
    func allTabs(bundleID: String) -> [Tab]? {
        guard let source = Self.allSources[bundleID],
              let text = run("all " + bundleID, source) else { return nil }
        return parse(text, bundleID: bundleID)
    }

    @discardableResult
    func setURL(_ url: String, at ref: TabRef) -> Bool {
        guard Self.supported.contains(ref.bundleID) else { return false }
        let quoted = "\"" + url.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
        let source = """
        with timeout of 1 second
          tell application id "\(ref.bundleID)"
            set URL of tab \(ref.tab) of window id \(ref.window) to \(quoted)
          end tell
        end timeout
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    private func run(_ key: String, _ source: String) -> String? {
        let script: NSAppleScript
        if let cached = compiled[key] {
            script = cached
        } else {
            guard let s = NSAppleScript(source: source) else { return nil }
            var compileError: NSDictionary?
            s.compileAndReturnError(&compileError)
            if compileError != nil { return nil }
            compiled[key] = s
            script = s
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue ?? ""
    }

    private func parse(_ text: String, bundleID: String) -> [Tab] {
        text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard f.count == 3, let w = Int(f[0]), let t = Int(f[1]), !f[2].isEmpty else { return nil }
            return Tab(ref: TabRef(bundleID: bundleID, window: w, tab: t), url: String(f[2]))
        }
    }
}
```

- [ ] **Step 5: Build**

Run: `swift build 2>&1 | tail -5` then `swift test 2>&1 | tail -3`.
Expected: build succeeds with no new warnings from `BrowserTabs.swift`; every test passes.

- [ ] **Step 6: Commit**

```bash
git add Resources/Blocking/blocked.html scripts/build-app.sh Sources/Tempo/System/BrowserTabs.swift
git commit -m "Blocked page, app bundle copy, and BrowserTabs AppleScript reads and writes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: BlockEnforcer, settings keys, startup, and tracker privacy

**Files:**
- Modify: `Sources/Tempo/AppSettings.swift`
- Create: `Sources/Tempo/BlockEnforcer.swift`
- Modify: `Sources/Tempo/AppDelegate.swift` (after `model.start()`)
- Modify: `Sources/Tempo/ActivityMonitor.swift` (the `.tab` case in `presence(at:)`)

**Interfaces:**
- Consumes: `BlockSchedule` (Task 3), `BlockPolicy` / `BlockAction` (Task 4), `AdultSites` (Task 1), `BrowserTabs` (Task 6), `TempoModel.shared.resolver`, `Format.clock(_:)`, `Log`.
- Produces: `AppSettings.Keys.blockEnabled`, `.blockWeekdayMask`, `.blockStartMinute`, `.blockEndMinute`, `AppSettings.blockSchedule: BlockSchedule`. `@MainActor final class BlockEnforcer: ObservableObject` with `static let shared`, `@Published private(set) var distractionWindow: DateInterval?`, `var isLocked: Bool`, `let adult: AdultSites`, `let adultListLoaded: Bool`, `func isAdult(_ host: String) -> Bool`, `func start()`, `func refreshWindow()`.

- [ ] **Step 1: Settings keys and the schedule**

In `Sources/Tempo/AppSettings.swift`, add to `enum Keys`:

```swift
        static let blockEnabled = "blockEnabled"
        static let blockWeekdayMask = "blockWeekdayMask"
        static let blockStartMinute = "blockStartMinute"
        static let blockEndMinute = "blockEndMinute"
```

Add to the `register(defaults:)` dictionary:

```swift
            Keys.blockEnabled: false, Keys.blockWeekdayMask: BlockSchedule.workweekMask,
            Keys.blockStartMinute: 540, Keys.blockEndMinute: 1020,
```

Add below `nudgeSettings`:

```swift
    /// The Distraction block window (site blocking spec 4.1). Defaults: off, Mon to Fri, 9 to 5.
    static var blockSchedule: BlockSchedule {
        let d = UserDefaults.standard
        return BlockSchedule(enabled: d.bool(forKey: Keys.blockEnabled),
                             weekdays: BlockSchedule.weekdays(mask: d.integer(forKey: Keys.blockWeekdayMask)),
                             startMinute: min(max(d.integer(forKey: Keys.blockStartMinute), 0), 1439),
                             endMinute: min(max(d.integer(forKey: Keys.blockEndMinute), 0), 1439))
    }
```

- [ ] **Step 2: Write BlockEnforcer**

`Sources/Tempo/BlockEnforcer.swift`:

```swift
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
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }
        if ticks % 5 == 0 {
            for id in running.sorted() {
                guard let all = tabs.allTabs(bundleID: id) else { logFailure(id, now: now); continue }
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
            if tabs.setURL(blockedPage(["kind": "adult"]), at: tab.ref) { Log.info("blocked an adult site") }
        case .blockDistraction(let site, let until):
            let page = blockedPage(["kind": "distraction", "site": site, "until": Format.clock(until)])
            if tabs.setURL(page, at: tab.ref) { Log.info("blocked \(site)") }
        case .rewrite(let url):
            // An engine that strips the parameter would reload forever; retry at most every 5 s.
            if let last = lastRewrite[tab.ref], last.from == tab.url { return }
            lastRewrite[tab.ref] = (tab.url, now)
            tabs.setURL(url, at: tab.ref)
        }
    }

    /// The bundled blocked page with its query, or about:blank in a dev build with no bundle.
    private func blockedPage(_ query: [String: String]) -> String {
        guard let url = Bundle.main.url(forResource: "blocked", withExtension: "html", subdirectory: "Blocking"),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "about:blank" }
        parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return parts.string ?? "about:blank"
    }

    private func logFailure(_ bundleID: String, now: Date) {
        if let last = lastFailureLog[bundleID], now.timeIntervalSince(last) < 60 { return }
        lastFailureLog[bundleID] = now
        Log.error("blocking: could not read tabs in \(bundleID)")
    }
}
```

(The rewrite guard needs no time check: `lastRewrite` entries older than 5 s are pruned at the top of every tick.)

- [ ] **Step 3: Start it at launch**

In `Sources/Tempo/AppDelegate.swift`, right after `model.start()`:

```swift
        BlockEnforcer.shared.start()
```

It starts even when the store failed to open: adult blocking and SafeSearch do not need rules.

- [ ] **Step 4: Record adult tabs like incognito**

In `Sources/Tempo/ActivityMonitor.swift`, the `.tab` case of `presence(at:)` becomes:

```swift
        case .tab(let url, let tabTitle)?:
            domain = Domain.normalize(url)
            if let tabTitle, !tabTitle.isEmpty { title = String(tabTitle.prefix(300)) }
            // An adult site is recorded like incognito: no title, no domain (site blocking spec 3.5).
            if let d = domain, BlockEnforcer.shared.isAdult(d) {
                title = nil
                domain = nil
            }
```

- [ ] **Step 5: Build and test**

Run: `swift build 2>&1 | tail -5` then `swift test 2>&1 | tail -3`.
Expected: build succeeds; every test passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/Tempo/AppSettings.swift Sources/Tempo/BlockEnforcer.swift Sources/Tempo/AppDelegate.swift Sources/Tempo/ActivityMonitor.swift
git commit -m "BlockEnforcer: 1 s front tab check, 5 s sweep, adult tabs never recorded

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The rule lock in the model, rules sheet, and inspector

**Files:**
- Modify: `Sources/Tempo/TempoModel.swift` (`setCategory`, `deleteRule`, new `isLocked`)
- Modify: `Sources/Tempo/Theme.swift` (new `LockedBadge` at the end)
- Modify: `Sources/Tempo/Views/Settings/RulesSheet.swift` (the row's menu and trash button)
- Modify: `Sources/Tempo/Views/Timeline/InspectorView.swift` (`ItemRow`'s `CategoryMenu`)

**Interfaces:**
- Consumes: `RuleLock.allows` (Task 5), `BlockEnforcer.shared.isLocked`, `.distractionWindow`, `.refreshWindow()` (Task 7), `CategoryMenu.labelWidth` (112).
- Produces: `TempoModel.isLocked(_ key: ItemKey) -> Bool`; `struct LockedBadge: View { let until: Date? }`.

- [ ] **Step 1: Guard rule changes in TempoModel**

In `Sources/Tempo/TempoModel.swift`, replace `setCategory` and `deleteRule` with:

```swift
    func setCategory(_ key: ItemKey, _ category: CategoryID) {
        if lockRefuses(key, category) { return }
        do { try store?.setUserRule(key, category: category, at: Date()) } catch { Log.error("set rule: \(error)") }
        reloadRules()
        refresh()
    }

    func deleteRule(_ key: ItemKey) {
        if lockRefuses(key, nil) { return }
        do { try store?.deleteRule(key, at: Date()) } catch { Log.error("delete rule: \(error)") }
        reloadRules()
        refresh()
    }

    /// True while a Distraction window runs and this site resolves to Distraction
    /// (site blocking spec 3.4). Views show a lock in place of its category menu.
    func isLocked(_ key: ItemKey) -> Bool {
        BlockEnforcer.shared.isLocked && key.kind == .domain && resolver.category(for: key) == .distraction
    }

    /// The one place the lock is enforced, so no path around the UI can take a site out of
    /// Distraction during a window. `category` nil means delete.
    private func lockRefuses(_ key: ItemKey, _ category: CategoryID?) -> Bool {
        let blocker = BlockEnforcer.shared
        blocker.refreshWindow()
        guard blocker.isLocked, !RuleLock.allows(key, newCategory: category, rules: rules) else { return false }
        Log.info("rule change for \(key.key) refused: Distraction block running")
        return true
    }
```

- [ ] **Step 2: Add LockedBadge**

At the end of `Sources/Tempo/Theme.swift`:

```swift
/// Stands in for a category menu while the Distraction block locks it (site blocking spec 3.4).
struct LockedBadge: View {
    let until: Date?

    private var text: String { until.map { "Locked until \(Format.clock($0))" } ?? "Locked" }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
            Text("Locked").font(Theme.ui(12, .semibold))
        }
        .padding(.horizontal, 8)
        .frame(width: CategoryMenu.labelWidth, height: 28, alignment: .leading)
        .foregroundStyle(Theme.ink)
        .background(Theme.chip, in: RoundedRectangle(cornerRadius: 8))
        .help(text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
```

- [ ] **Step 3: Use it in the rules sheet**

In `Sources/Tempo/Views/Settings/RulesSheet.swift`, add to the struct's properties:

```swift
    @ObservedObject private var blocker = BlockEnforcer.shared
```

and replace the row's `CategoryMenu(...)` line and the trash `Button { ... }` block (through its `.accessibilityLabel(...)`) with:

```swift
                    if model.isLocked(rule.key) {
                        LockedBadge(until: blocker.distractionWindow?.end)
                        Image(systemName: "trash").hidden()
                    } else {
                        CategoryMenu(current: rule.category ?? .uncategorized) { model.setCategory(rule.key, $0) }
                        Button { model.deleteRule(rule.key) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove rule")
                            .accessibilityLabel("Remove rule for \(name(for: rule))")
                    }
```

- [ ] **Step 4: Use it in the inspector**

In `Sources/Tempo/Views/Timeline/InspectorView.swift`, in `struct ItemRow` add:

```swift
    @ObservedObject private var blocker = BlockEnforcer.shared
```

and replace

```swift
            CategoryMenu(current: item.category) { model.setCategory(item.key, $0) }
```

with

```swift
            if model.isLocked(item.key) {
                LockedBadge(until: blocker.distractionWindow?.end)
            } else {
                CategoryMenu(current: item.category) { model.setCategory(item.key, $0) }
            }
```

- [ ] **Step 5: Build and test**

Run: `swift build 2>&1 | tail -5` then `swift test 2>&1 | tail -3`.
Expected: build succeeds; every test passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/Tempo/TempoModel.swift Sources/Tempo/Theme.swift Sources/Tempo/Views/Settings/RulesSheet.swift Sources/Tempo/Views/Timeline/InspectorView.swift
git commit -m "Lock Distraction rules while the block runs: model guard and lock badges

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Settings Blocking section, Permissions copy, and the menu line

**Files:**
- Modify: `Sources/Tempo/Views/Settings/SettingsView.swift`
- Modify: `Sources/Tempo/Theme.swift` (new `DayChip` at the end)
- Modify: `Sources/Tempo/Views/MenuBarView.swift`

**Interfaces:**
- Consumes: `AppSettings.Keys.block*` and `BlockEnforcer.shared` (Task 7), `BlockSchedule.workweekMask` (Task 3), `StatusChip`, `Format.clock`.
- Produces: `struct DayChip: View { label: String; on: Bool; action: () -> Void }`.

- [ ] **Step 1: Add DayChip**

At the end of `Sources/Tempo/Theme.swift`:

```swift
/// A weekday toggle in the Distraction block schedule: ink when on, chip color when off.
struct DayChip: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(Theme.ui(12.5, .semibold))
                .frame(width: 42, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(on ? Color.white : Theme.ink)
        .background(on ? Theme.ink : Theme.chip, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
```

- [ ] **Step 2: Settings state**

In `Sources/Tempo/Views/Settings/SettingsView.swift`, add to the properties:

```swift
    @AppStorage(AppSettings.Keys.blockEnabled) private var blockEnabled = false
    @AppStorage(AppSettings.Keys.blockWeekdayMask) private var blockWeekdayMask = BlockSchedule.workweekMask
    @AppStorage(AppSettings.Keys.blockStartMinute) private var blockStartMinute = 540
    @AppStorage(AppSettings.Keys.blockEndMinute) private var blockEndMinute = 1020
    @ObservedObject private var blocker = BlockEnforcer.shared

    /// Monday first, as Calendar weekday numbers.
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
```

- [ ] **Step 3: The Blocking section**

Insert between the closing `}` of `section("Nudges") { ... }` and `section("Sorting") {`:

```swift
                section("Blocking") {
                    row("Adult sites", "Always blocked in Chrome and Safari, including private windows. SafeSearch is always on for Google, Bing, and DuckDuckGo.") {
                        if blocker.adultListLoaded {
                            StatusChip(text: "\(blocker.adult.count.formatted()) sites")
                        } else {
                            StatusChip(text: "List missing", foreground: Self.red, background: Self.redSoft)
                        }
                    }
                    divider
                    distractionBlockRow
                }
```

Add these members to `SettingsView` (next to `divider`):

```swift
    private var blockDetail: String {
        let base = "Blocks every site in Distraction during these hours. Locked while it runs."
        return blockEndMinute <= blockStartMinute ? base + " Ends the next day." : base
    }

    private var distractionBlockRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distraction block").font(Theme.ui(14, .semibold))
                    Text(blockDetail).font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 400, alignment: .leading)
                Spacer(minLength: 12)
                if let w = blocker.distractionWindow {
                    StatusChip(text: "Locked until \(Format.clock(w.end))", foreground: Theme.ink, background: Theme.chip)
                }
                Toggle("Distraction block", isOn: $blockEnabled).toggleStyle(.switch).labelsHidden().tint(Theme.ink)
                    .disabled(blocker.isLocked)
            }
            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { day in
                    DayChip(label: Calendar.current.shortWeekdaySymbols[day - 1],
                            on: blockWeekdayMask & (1 << (day - 1)) != 0) {
                        blockWeekdayMask ^= (1 << (day - 1))
                    }
                }
                Spacer(minLength: 16)
                Text("From").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                DatePicker("Start", selection: minuteBinding($blockStartMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("To").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                DatePicker("End", selection: minuteBinding($blockEndMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .disabled(blocker.isLocked)
            .opacity(blocker.isLocked ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    /// A minutes-after-midnight setting as today's date at that time, for DatePicker.
    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }
```

Add these next to the other `.onChange` modifiers so a change applies (and locks) right away:

```swift
        .onChange(of: blockEnabled) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockWeekdayMask) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockStartMinute) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockEndMinute) { _, _ in BlockEnforcer.shared.refreshWindow() }
```

- [ ] **Step 4: Permissions copy**

In the Permissions section, change the Chrome and Safari detail strings to:

```swift
                    permissionRow("Chrome", "Reads the current tab, and swaps in the blocked page for blocked sites.", chrome) {
```

```swift
                    permissionRow("Safari", "Same as Chrome. Asks the first time Safari runs with Tempo running.", safari) {
```

- [ ] **Step 5: The menu line**

In `Sources/Tempo/Views/MenuBarView.swift`, add to `MenuBarView`:

```swift
    @ObservedObject private var blocker = BlockEnforcer.shared
```

and between `FocusTimerSection()` and `PauseSection()`:

```swift
            if let w = blocker.distractionWindow {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .semibold))
                    Text("Blocking Distraction until \(Format.clock(w.end))").font(Theme.ui(13.5, .semibold))
                }
            }
```

- [ ] **Step 6: Build and test**

Run: `swift build 2>&1 | tail -5` then `swift test 2>&1 | tail -3`.
Expected: build succeeds; every test passes.

- [ ] **Step 7: Commit**

```bash
git add Sources/Tempo/Views/Settings/SettingsView.swift Sources/Tempo/Theme.swift Sources/Tempo/Views/MenuBarView.swift
git commit -m "Settings Blocking section, Permissions copy, and the menu lock line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Docs, install, and first live check

**Files:**
- Modify: `README.md`
- Modify: `docs/hands-on-checklist.md`
- Modify: `docs/superpowers/specs/2026-09-30-tempo-site-blocking-design.md` (Status line)

- [ ] **Step 1: README**

Add this section after "Permissions":

```markdown
## Blocking

- Adult sites are always blocked in Chrome and Safari, including incognito and private windows.
  The list is a fixed snapshot of OISD's NSFW small list (21,192 sites, 2026-09-30) in
  `Resources/Blocking/`, plus any site with porn, xxx, or hentai in its name. There is no switch.
- SafeSearch is always forced on Google, Bing, and DuckDuckGo.
- Distraction sites are blocked during one weekly window set in Settings, Blocking. While it runs,
  the schedule is locked and no site can be moved out of Distraction.
- Tempo checks the front tab every second and every tab every 5 seconds, and swaps a blocked tab
  for its own blocked page. Blocking keeps running when tracking is paused or stopped. Quitting
  Tempo turns it off.
```

In "Permissions", change the Automation bullet to:

```markdown
- Automation: approve Tempo controlling Chrome and Safari when macOS asks. That is how it reads
  the site in the active tab, and how it swaps in the blocked page.
```

In "Privacy", replace the paragraph with:

```markdown
Chrome incognito windows and adult sites are not recorded (no title, no site). Blocking reads
every tab, incognito and private ones included, but never stores what it reads. Safari Private
windows are not detected for tracking, so they are recorded like any other window.
```

- [ ] **Step 2: Hands-on checklist**

Append to `docs/hands-on-checklist.md`:

```markdown
## Site blocking

- [ ] After install, re-grant Accessibility, then approve "Tempo wants to control Google Chrome" and the Safari prompt if they appear again.
- [ ] Settings, Blocking: the adult row shows "21,192 SITES". The Distraction row shows Mon to Fri, 9:00 AM to 5:00 PM, switched off.
- [ ] Adult: open a known adult site in a normal Chrome tab, a Chrome incognito window, and a Safari private window. Each is replaced by "This site is blocked." within about a second.
- [ ] Adult privacy: afterwards, the segments query from "Tracking accuracy" shows no adult domain or title, and `grep -i porn ~/Library/Logs/Tempo.log` shows only "blocked an adult site" lines.
- [ ] SafeSearch: a Google image search, a Bing search, and a DuckDuckGo search each reload once with safe=active, adlt=strict, or kp=1 in the address.
- [ ] Distraction: set the window to start a minute from now and switch it on. When it starts, an open YouTube tab (front and background) is replaced within 5 seconds with "youtube.com is blocked until ...". Back from the blocked page is replaced again.
- [ ] Lock: during the window the switch, days, and times are disabled with "Locked until ...". In Rules, youtube.com shows the lock badge; github.com can still be moved to Distraction. In the timeline inspector, a Distraction site shows the lock badge.
- [ ] The menu shows "Blocking Distraction until ..." during the window and nothing after it.
- [ ] Outside the window, YouTube loads normally and every control is editable.
- [ ] Stop tracking: blocking still works while tracking is stopped.
```

- [ ] **Step 3: Spec status**

In the spec, change `Status: approved in chat 2026-09-30, not built` to `Status: built on tempo-site-blocking, live checks pending`.

- [ ] **Step 4: Full test run and install**

Run: `swift test 2>&1 | tail -3` (every test passes), then `scripts/install.sh`.
Expected: "installed and started". Then check:

```bash
ls /Applications/Tempo.app/Contents/Resources/Blocking/
pgrep -x Tempo
tail -20 ~/Library/Logs/Tempo.log
```

Expected: `blocked.html` and `oisd-nsfw-small.txt` are listed, Tempo is running, and the log has no "adult list missing" line.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/hands-on-checklist.md docs/superpowers/specs/2026-09-30-tempo-site-blocking-design.md
git commit -m "Docs: blocking in the README, hands-on checklist, spec status

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
