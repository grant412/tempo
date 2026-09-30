# Tempo: Site blocking (design)

Date: 2026-09-30
Status: built on tempo-site-blocking, live checks pending
Builds on: `2026-09-26-tempo-design.md` (sections 6 activity, 7 rules), `2026-09-26-tempo-focus-timer-design.md`
Branch: `tempo-site-blocking`, off `main`

## 1. Summary

Tempo blocks sites in Chrome and Safari, the only browsers on this Mac. It already reads the
active tab through AppleScript; the same Automation permission lets it set a tab's URL. When a
tab is on a blocked site, Tempo replaces it with its own blocked page.

1. **Adult sites.** Blocked all the time, in normal, incognito, and private windows. No switch.
2. **Distraction sites.** Every site in the Distraction category is blocked during one scheduled
   window (days plus a start and end time). While the window runs, Tempo's ways out are locked.
3. **SafeSearch.** Always forced on for Google, Bing, and DuckDuckGo searches.

Blocking runs whether tracking is on, paused, or stopped. Quitting Tempo is the only way to turn
it off.

## 2. Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Mechanism | Tempo swaps the tab's URL through AppleScript (option 1). No hosts file, no root helper. |
| Browsers | Chrome and Safari (the only two installed). |
| Distraction block list | The Distraction category itself: every domain whose rules resolve to Distraction, including ones added later by Grant or Claude. |
| When Distraction blocks | One scheduled window: chosen weekdays, one start time, one end time. |
| Override | None. The blocked page has no button. |
| Lock during the window | Locked: the schedule, its on/off switch, and any rule change that would take a domain out of Distraction. Adding sites to Distraction still works. |
| Apps | Not blocked. Sites only. |
| Adult sites, when | Always, locked. No switch anywhere in Tempo. |
| Adult detection | OISD NSFW small list (21,192 entries, the most-visited adult sites: 20,992 of them rank in the Tranco top 1 million), plus the words porn, xxx, hentai in the host, plus the list's single-label entries (.adult, .porn, .sex, .xxx). |
| Adult list updates | None. A fixed snapshot (OISD version 202609301216) ships inside the app. No downloads. |
| HaGeZi list | Not used (it also blocks Tinder, Match, Badoo, Character.AI, 4chan). |
| Claude check for unknown adult sites | Not used. |
| SafeSearch | Forced on Google, Bing, and DuckDuckGo, always. |
| Privacy | Adult sites are never saved to the timeline or sent to Claude. Incognito and private tabs are read to enforce blocking, never recorded. |

## 3. Behavior

### 3.1 What gets blocked

For each tab URL, in this order:

1. Not `http` or `https` (the blocked page itself, `chrome://`, `about:`, `file://`): allowed.
2. **Adult** (always): the host matches the adult list (section 5.1), contains a blocked word, or
   ends in a blocked single-label entry. The tab gets the adult blocked page.
3. **Distraction** (only inside the window): the host resolves to Distraction with the same
   `RuleResolver` tracking uses (exact host, then each parent down to two labels). So a
   `youtube.com` rule also blocks `m.youtube.com`. The tab gets the Distraction blocked page.
4. **SafeSearch** (always): a Google, Bing, or DuckDuckGo search URL without the strict parameter
   gets the same URL back with it set (section 5.1). The tab reloads with SafeSearch on.
5. Anything else: allowed.

A domain Tempo has not sorted yet is not in Distraction, so it is not blocked until it is sorted
there (by Grant, or by Claude on its next pass).

### 3.2 How often Tempo checks

- **Every second,** when Chrome or Safari is the frontmost app: the active tab of its front window.
- **Every 5 seconds,** for each of Chrome and Safari that is running: every tab in every window,
  including incognito and private windows and background tabs.
- A browser that is not running is never sent an Apple Event (a `tell` would launch it).

So a blocked site in the tab Grant is looking at shows for about a second at most, and one
playing in a background tab is caught within 5 seconds. When a window starts, every open
Distraction tab is replaced within 5 seconds.

Going Back from the blocked page loads the site again, and it is replaced again within a second.

### 3.3 Blocked page

A local HTML page shipped in the app at `Tempo.app/Contents/Resources/Blocking/blocked.html`,
opened as a `file://` URL with a query string:

- Distraction: `?kind=distraction&site=youtube.com&until=5%3A00%20PM`. Shows
  "youtube.com is blocked until 5:00 PM." with a small "Distraction block" eyebrow.
- Adult: `?kind=adult`. Shows "This site is blocked." and never names the site.

The page reads its query with a few lines of script and fills in the text (the text is inserted
as text, never as HTML). Tab title: "Blocked". Styling follows Tempo: paper background
`#f6f3ec`, ink `#1d1b18`, muted `#6b655b`, one centered white card with a `#e7e1d5` border.
Fonts are a system stack (`-apple-system, system-ui, sans-serif`); Chrome will not load the
bundled fonts over `file://`.

If the page is missing (a `swift run` dev build has no app bundle), Tempo uses `about:blank`.

### 3.4 The lock

While a Distraction window runs:

- **Settings:** the Distraction block switch, the day chips, and both times are disabled. A chip
  reads "Locked until 5:00 PM".
- **Rules:** a change is refused when the domain resolves to Distraction now and would not after
  the change. That covers moving a Distraction site to another category, deleting its rule, and
  adding a rule that splits a subdomain out (for example `music.youtube.com` to Research while
  `youtube.com` is Distraction). App rules are never locked. Adding or moving a site into
  Distraction works.
- In the Rules sheet and the timeline inspector, locked rows show a lock icon in place of the
  category menu and trash button, with the tooltip "Locked until 5:00 PM".
- `TempoModel.setCategory` and `deleteRule` enforce the same check, so no path around the UI
  can make the change.

Outside the window everything is editable, including a schedule change that starts a window
right now.

### 3.5 Tracking and privacy

- When the tracker (`ActivityMonitor`) reads a tab whose host is adult, it drops the title and
  domain, the same way it handles incognito today. The segment is recorded as the browser with
  no title, and the domain never reaches the classifier queue or Claude.
- The blocker reads incognito and private tabs to enforce blocking. Those reads live in memory
  for one check and are never written anywhere.
- The log names Distraction sites it blocks ("blocked youtube.com") but never adult ones
  ("blocked an adult site").

## 4. Screens

### 4.1 Settings: new Blocking section

Placed between Nudges and Sorting, built from the existing `section` and `row` helpers.

```
Blocking
+----------------------------------------------------------------------+
| Adult sites                                          [21,192 sites]  |
| Always blocked in Chrome and Safari, including private windows.      |
| SafeSearch is always on for Google, Bing, and DuckDuckGo.            |
+----------------------------------------------------------------------+
| Distraction block                                          [switch]  |
| Blocks every site in Distraction during these hours. Locked          |
| while it runs.                                                       |
|   [Mon][Tue][Wed][Thu][Fri][Sat][Sun]    From [ 9:00 AM ] To [ 5:00 PM ] |
|   During a window: [Locked until 5:00 PM] and every control disabled |
+----------------------------------------------------------------------+
```

- Day chips toggle on click; selected chips use the ink fill, unselected the chip color
  (`Theme.chip`), like `SmallButton(fill:)`.
- Times use `DatePicker` with `.hourAndMinute`, labels hidden.
- The switch, day chips, and times edit a draft. Save writes all four settings at once (Cancel
  reverts). If the draft covers now, Save first asks "Start the Distraction block now?" with
  the lock's end time, so an in-between edit can never start a lock.
- An end time at or before the start time runs past midnight (9:00 PM to 1:00 AM). The detail
  line then adds "Ends the next day." Equal times mean a full 24 hours.
- The adult row chip shows the loaded entry count. If the list failed to load, it shows a red
  "List missing" chip instead.
- Defaults: switch off, Mon to Fri, 9:00 AM to 5:00 PM.

### 4.2 Menu bar dropdown

While a Distraction window runs, one line sits between the focus timer section and Pause
tracking: a `lock.fill` symbol and "Blocking Distraction until 5:00 PM" (`Theme.ui(13.5, .semibold)`).
Nothing is shown for adult blocking, since it is always on.

### 4.3 Permissions rows

- Chrome: "Reads the current tab, and swaps in the blocked page for blocked sites."
- Safari: "Same as Chrome. Asks the first time Safari runs with Tempo running."

## 5. Architecture

### 5.1 TempoCore (pure, unit tested)

**`AdultSites`** (new, `AdultSites.swift`)
- `init(listText: String)`: parses OISD text. Skips blank lines and `#` comments, trims,
  lowercases, strips a leading `*.` and `www.`. Entries with one label go to a TLD set, the rest
  to a domain set.
- `count: Int`: entries loaded.
- `static let words = ["porn", "xxx", "hentai"]`.
- `func contains(host: String) -> Bool`: false for hosts with a port or an IPv4 address.
  Otherwise true when the host contains a word, its last label is in the TLD set, or any of
  `Domain.candidates(for: host)` is in the domain set. (`thisexample.com` does not match
  `example.com`.)

**`SafeSearch`** (new, `SafeSearch.swift`)
- `static func enforced(_ url: String) -> String?`: the URL with the engine's strict parameter
  set, or nil when it is not a search on these engines or already has it.
  - Google: host (after `www.`) is `google.<tld>`, `google.co.<cc>`, or `google.com.<cc>`; path
    `/search`. Sets `safe=active`.
  - Bing: host `bing.com` or `*.bing.com`; path `/search`, `/images/search`, or `/videos/search`.
    Sets `adlt=strict`.
  - DuckDuckGo: host `duckduckgo.com`, `html.duckduckgo.com`, or `lite.duckduckgo.com`; a
    non-empty `q`. Sets `kp=1`.
- Uses `URLComponents.percentEncodedQueryItems`, so every other parameter keeps its exact
  encoding (`+` stays `+`). An existing parameter of the same name with another value is replaced.

**`BlockSchedule`** (new, `BlockSchedule.swift`)
- Fields: `enabled: Bool`, `weekdays: Set<Int>` (Calendar weekday numbers, 1 is Sunday),
  `startMinute: Int`, `endMinute: Int` (minutes after midnight, 0 to 1439).
- `func window(containing date: Date, calendar: Calendar) -> DateInterval?`: nil when disabled.
  A window belongs to the day it starts on: it checks the window starting today and the one
  starting yesterday. Start and end are wall-clock times built from the day's date components, so DST
  days keep the chosen times. End after start: same day. End at or before start: next day at
  the end time. Start inclusive, end exclusive.
- `func lock(containing date: Date, calendar: Calendar) -> DateInterval?`: the window containing
  `date`, extended while a window starts exactly at its end (equal times on neighboring selected
  days). After 8 joins the end is `.distantFuture`, a lock that never ends.
- `func neverUnlocks(calendar: Calendar) -> Bool`: true when enabled and the lock from some
  window start in one week never ends.

**`Format.lockEnd(_ end: Date, now: Date, calendar: Calendar) -> String`** (added to
`Format.swift`): "5:00 PM" when the end is today, "tomorrow at 1:00 AM", "Friday at 9:00 AM" on
a later day, "further notice" for `.distantFuture`. Every surface that shows a lock end uses it.

**`BlockPolicy`** (new, `BlockPolicy.swift`)
- `enum BlockAction: Equatable { case allow, blockAdult, blockDistraction(site: String, until: Date), rewrite(String) }`
- `struct BlockPolicy { adult: AdultSites; resolver: RuleResolver; window: DateInterval? }`
- `func action(for url: String) -> BlockAction`: section 3.1 in order. The host comes from
  `Domain.normalize(url)`; nil means `.allow`.

**`RuleLock`** (new, `RuleLock.swift`)
- `static func allows(_ key: ItemKey, newCategory: CategoryID?, rules: [Rule]) -> Bool`.
  `newCategory` nil means delete. Apps always true. For domains: false when the category under
  `rules` is Distraction and the category under `rules` with this key replaced (nil category for
  a delete, which the resolver skips like a tombstone) is not.
- Only consulted while a window runs.

### 5.2 Tempo app

**`BrowserTabs`** (new, `System/BrowserTabs.swift`, `@MainActor`)
- `struct TabRef: Hashable { bundleID; window: Int; tab: Int }`: 1-based window index (window 1
  is the front window) plus 1-based tab index in both browsers (the read and the write happen in
  the same tick). Not the window id: Chrome declares it as text, with values often too big for an
  AppleScript integer.
- `func frontTab(bundleID:) -> Tab?` and `func allTabs(bundleID:) -> [Tab]?` (nil when the read
  failed), where `Tab` is a `TabRef` plus its URL.
  Compiled `NSAppleScript`s cached per browser, `with timeout of 1 second`. The front-tab script
  reads `window 1` and returns `1` as its window index. The all-tabs script loops
  `repeat with wi from 1 to count of windows`, reads `URL of every tab of window wi` per window
  (Apple Events per window, not per tab), wraps each window in `try`, and joins fields with
  `character id 9` (the word `tab` means a tab object inside `tell application "Google Chrome"`).
- `func setURL(_ url: String, at ref: TabRef) -> Bool`: builds a one-off script
  (`set URL of tab T of window W` in both browsers)
  with the URL escaped for AppleScript (backslash and double quote).
- Callers check `NSRunningApplication.runningApplications(withBundleIdentifier:)` first.
- The tracker's `BrowserTabReader` stays as it is.

**`BlockEnforcer`** (new, `BlockEnforcer.swift`, `@MainActor`, `ObservableObject`, shared)
- Loads `AdultSites` once from `Bundle.main` `Blocking/oisd-nsfw-small.txt`; missing or
  unreadable logs an error and uses an empty list (words and nothing else still work).
- `@Published private(set) var distractionWindow: DateInterval?`: the Distraction lock running now
  (`BlockSchedule.lock(containing:calendar:)`, so its end is when blocking really stops),
  assigned only when it changes so views do not redraw every second.
- `func isAdult(_ host: String) -> Bool` for the tracker.
- A 1 second `Timer` on the main run loop (`.common` mode), started from `TempoModel.start()`
  after rules load. Each tick: recompute `distractionWindow` from `AppSettings.blockSchedule`; every fifth
  tick sweep all tabs of each running supported browser; otherwise check the front tab when the
  frontmost app is a supported browser.
- For each tab: `BlockPolicy(adult:, resolver: TempoModel.shared.resolver, window:)`. Blocks call
  `setURL` with the blocked page URL (`Format.lockEnd(until, now:, calendar:)` for the time). A rewrite is skipped
  when the same tab was rewritten from the same URL in the last 5 seconds (guards a reload loop
  if an engine strips the parameter).
- Failed reads or writes skip that check and are logged at most once a minute per browser.

**`AppSettings`**: keys `blockEnabled` (false), `blockWeekdayMask` (62, Monday to Friday; bit `weekday - 1`),
`blockStartMinute` (540), `blockEndMinute` (1020), and `static var blockSchedule: BlockSchedule`.
`static func saveBlockSchedule(_:) -> Bool` writes all four at once, and refuses (false, nothing
written) while a block runs.

**`ActivityMonitor`**: in the `.tab` case, when `BlockEnforcer.shared.isAdult(domain)`, set title
and domain to nil.

**`TempoModel`**: `setCategory` and `deleteRule` return early (logged) when a window runs and
`RuleLock.allows` is false. New `func isLocked(_ key: ItemKey) -> Bool`: a window runs, the key is
a domain, and it resolves to Distraction.

**Views**: `SettingsView` Blocking section and Permissions text; `MenuBarView` lock line;
`RulesSheet` and `InspectorView` lock icon for locked keys. Each observes `BlockEnforcer.shared`.

**Resources and build**: new `Resources/Blocking/blocked.html` and
`Resources/Blocking/oisd-nsfw-small.txt` (the 2026-09-30 snapshot, header kept, OISD license
noted in the header). `scripts/build-app.sh` copies `Resources/Blocking/` into
`Contents/Resources/Blocking/`.

**Docs**: README gets a Blocking section and updated Privacy and Permissions notes; the hands-on
checklist gets a Blocking section.

## 6. Error handling

| Case | Behavior |
|---|---|
| Automation denied or a read times out | Skip that check; logged at most once a minute per browser. Settings already shows the permission state. |
| Browser not running | No Apple Events sent. |
| Adult list missing or unreadable | Words and nothing else; Settings shows "List missing"; logged once. |
| Blocked page missing | `about:blank`. |
| SafeSearch parameter stripped by the engine | 5 second per-tab guard stops a reload loop. |
| Store failed to open | Resolver is empty, so Distraction blocking does nothing; adult and SafeSearch still work. |
| Mac asleep | The timer resumes on wake; the next tick applies the current window. |

## 7. Testing

Unit tests (Swift Testing, TempoCore):

- `AdultSites`: comments, blanks, case, `www.` and `*.` stripping; exact and subdomain matches;
  no suffix-substring match; TLD entries; each word; hosts with a port and IPv4 hosts never
  match. The shipped list (read from the repo by `#filePath`) loads 21,192 entries, contains
  `pornhub.com`, and does not contain `reddit.com`, `x.com`, `google.com`, `tumblr.com`, or
  `imgur.com`.
- `SafeSearch`: Google `.com`, `.de`, `.co.uk`, `.com.au`, with and without `www.`; `/search`
  only; `safe=off` replaced; already `active` gives nil; other parameters keep their encoding;
  `google.evil.com` gives nil; Bing's three paths and a subdomain; DuckDuckGo with and without `q`;
  a non-search host gives nil.
- `BlockSchedule`: disabled; weekday in and out; start inclusive and end exclusive; an overnight
  window belongs to its start day (Fri 9 PM to 1 AM covers Sat 12:30 AM with only Fri selected,
  not Sat 12:30 AM with only Sat selected); equal times are 24 hours; a DST day keeps wall-clock
  times. `lock`: a normal window is its own lock; Mon to Fri 9:00 AM to 9:00 AM from Monday
  10 AM ends Saturday 9 AM; all seven days 12:00 AM to 12:00 AM never ends (`neverUnlocks` is
  true), while Mon to Fri 9 to 5 unlocks.
- `Format.lockEnd`: today, tomorrow, a weekday name, "further notice", and the calendar's time
  zone.
- `BlockPolicy`: adult wins over everything and applies outside the window; Distraction only
  inside it; a subdomain blocked by its parent's rule; SafeSearch rewrite outside the window;
  non-http URLs, including the blocked page, are allowed.
- `RuleLock`: moving a Distraction site out, deleting its rule, and splitting a subdomain out are
  refused; moving a site in, changing a non-Distraction site, and any app rule are allowed;
  deleting a subdomain rule whose parent is also Distraction is allowed.

Hands-on (Grant at the Mac, added to `docs/hands-on-checklist.md`): Automation prompts after
install; an adult site in a normal tab, an incognito tab, and a Safari private window; a
Distraction site inside and outside the window, in a front tab and a background tab; Back from
the blocked page; a Google image search, a Bing search, and a DuckDuckGo search each reload with
SafeSearch; the lock in Settings, the Rules sheet, and the inspector; the menu line; an adult
visit leaves no domain or title in the segments table.

## 8. Out of scope and known gaps

- Browsers other than Chrome and Safari. A newly installed browser gets around blocking.
- Quitting Tempo turns blocking off until the next login.
- Adult sites that are on neither the snapshot nor caught by the words. The snapshot never
  updates on its own; refreshing it means replacing the file and rebuilding.
- Other search engines (Yahoo, Brave Search, Ecosia) and YouTube Restricted Mode.
- App blocking.
- Time on the blocked page is tracked as the browser (Chrome and Safari sort as Research).
