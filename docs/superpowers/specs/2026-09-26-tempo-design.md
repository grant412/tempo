# Tempo: personal automatic time tracker (design)

Date: 2026-09-26
Status: approved design, ready for implementation plan
Owner: Grant Feltz (personal tool, not an Overdrive product)

## 1. Summary

Tempo is a native macOS menu-bar app that records what Grant is actually doing at the keyboard
(front app, window title, browser tab), sorts it into categories, and shows the day as a
vertical calendar of colored blocks. It nudges him to take a break after a long stretch and
when he has been in Distraction too long. Everything stays on the Mac except one small,
one-time lookup per unknown app or site, which goes to Claude Haiku to guess its category.

It is a Rize clone for one person. It launches at login, restarts itself if it crashes, and
lives in its own repo at `~/Desktop/tempo` (local git, no remote).

## 2. Goals and non-goals

Goals (v1):
- Automatic tracking with no manual timers.
- Day timeline in the vertical calendar layout from the locked mockups.
- Break nudge and distraction nudge.
- One-click recategorizing that re-sorts every day, past and future.
- Claude fallback for apps and sites Tempo has never seen.
- Launch at login, crash restart, data loss under a minute on a crash.

Non-goals (v1): focus score, weekly report or trends, projects/clients/billing, dark mode,
editing or adding categories, multi-device sync, Windows, screenshots or screen content,
manual time entry, exports.

## 3. Look (locked)

Mockups: Tempo canvas, page "Calendar", https://claude.ai/artifact/NcSz9NHBNHC9tgLXtXDFRB
(artboards: Calendar light, Menu bar, Nudges, Settings). Light mode only. The dark
calendar artboard is reference only and does not ship.

Tokens:

| Token | Hex | Use |
|---|---|---|
| bg | `#f6f3ec` | Window ground |
| panel | `#ffffff` | Cards, popover, inspector |
| line | `#e7e1d5` | Borders, dividers |
| grid | `#ece6da` | Hour lines |
| grid2 | `#f3efe7` | Half-hour dashed lines |
| ink | `#1d1b18` | Text, now line, selection ring, primary button, switches on |
| muted | `#6b655b` | Secondary text |
| chip | `#f1ece2` | Pills, app initials, week-strip track |
| track | `#efeae0` | Bar tracks |
| granted | `#15924b` on `#e4f5ea` | Permission "Granted" chip only |

No amber or orange attention fills anywhere. "Needs a category" uses a white panel and the
striped Uncategorized swatch.

Type: Bricolage Grotesque 800 for display numbers and headings, Geist for UI text, Geist Mono
for times and durations (tabular). All three are OFL and ship inside the app bundle.

Categories (fixed set in v1; order is the stacking order in bars and the week strip):

| id | Name | Fill | Label text | Distraction |
|---|---|---|---|---|
| code | Code | `#2870cc` | white | no |
| design | Design | `#eb6834` | ink | no |
| comms | Communication | `#1baf7a` | ink | no |
| meet | Meetings | `#eda100` | ink | no |
| writing | Writing | `#e87ba4` | ink | no |
| research | Research | `#008300` | white | no |
| admin | Admin | `#4a3aa7` | white | no |
| distraction | Distraction | `#ec5f5e` | ink | yes |
| uncategorized | Uncategorized | stripes `#b8b3a8`/`#c9c4ba` at 135° | ink | no |

Every fill and label pair clears 4.5:1. The eight hues passed the colorblind validator
(adjacent CVD delta E 9.1 or better). Blocks always carry a text label or tooltip, so color
never carries meaning alone.

## 4. Screens

### 4.1 Menu bar item
Label: the three-blocks glyph plus today's total in Geist Mono ("8h 41m"). Shows "Paused"
while paused. Clicking opens a 348pt popover (SwiftUI `MenuBarExtra`, window style):
- "Today so far" total (display 46pt) and "at the keyboard since 8:12 AM".
- The live block, drawn like a timeline block (category fill, name, LIVE badge, duration,
  "4:32 PM to now, Claude, Terminal"). Hidden when idle or paused.
- Category rows: swatch, name, bar scaled to the top category, duration. Only non-zero.
- Pause tracking: 30 min, 1 hour, Until tomorrow (resumes at next local midnight). While
  paused this row becomes "Paused until 3:15 PM" plus a Resume button.
- Open timeline (ink primary button), then Settings and Quit Tempo.

### 4.2 Timeline window (1280x820 default, min 1100x720)
Toolbar: traffic lights, "Tempo" wordmark, previous/next day, date title ("Today, Thursday,
Sep 24" or "Wednesday, Sep 23"), status pill (Tracking, Paused, or Needs permission), Pause
button, Settings button.

Left column (272pt):
- This week: seven day columns Mon to Sun for the week of the shown day. Each has a stacked
  bar (84pt = 10h) in category order and a date pill; the shown day's pill is ink. Click to
  jump to that day. Header shows the week total.
- Day stats: total at the keyboard (display 46pt), first activity time, longest stretch
  (longest block), distraction total.
- Category list for the day: swatch, name, bar, duration, sorted by time.

Center, the timeline:
- Vertical, 1pt per minute, scrolls. Default visible range is 8 AM to 6 PM, widened to the
  hour before the first activity and the hour after the last activity (or now). Opens
  scrolled to show now (today) or the first activity (past days).
- Hour labels in the gutter, solid hour lines, dashed half-hour lines.
- Blocks per section 8: full category fill, 8pt radius, 2pt gap. Label layout by height:
  40pt and up is two lines (name, LIVE badge if live, duration; then "time range, top
  apps"); 18 to 39pt is one line (name, apps, duration); under 18pt has no label but keeps
  a tooltip.
- Away gaps of 5 minutes or more are hatched, labeled "Away, 43m" when 24pt or taller.
- Selected block: 2pt panel ring plus 2pt ink ring.
- Today only: ink now line with a dot and a time pill in the gutter.
- Nudge markers: 24pt ink circle with a bell, straddling the right edge at the nudge time.
  Header legend: "Click any block to see what was inside." plus a bell chip "nudge sent".

Right column, the inspector (330pt):
- Header in the selected block's fill: "Selected block", category name and duration
  (display 34pt), time range.
- "What was inside": one row per item key (section 7.2) inside the block, sorted by time:
  initial avatar, name, duration, a bar in the item's category color, and a category picker
  button. Folded short items show their own category.
- Footnote: "Short switches under 2 minutes stay inside the block. Change any category and
  every day re-sorts."
- Needs a category (bottom, hidden when nothing qualifies): the uncategorized key with the
  most time on the shown day, its time, and quick chips for the day's three most-used
  categories plus More (full picker).
- Default selection: the live block on today, otherwise the longest block.

### 4.3 Nudges
Standard macOS notifications (`UNUserNotificationCenter`) from Tempo, using the app icon
(three stacked blocks in blue, aqua, violet on ink).
- Break: title "Time for a break", body "You've been at it for {N} minutes straight. A five
  minute break resets the clock."
- Distraction: title "{N} minutes on Distraction", body "You've been on {top one or two
  names} since {h:mm}. Ready to get back to it?"
Clicking a notification opens the timeline on today.

### 4.4 Settings window (760pt wide)
Sections from the mockup: General (Open at login, Stop counting after N min, Your data path
plus Show in Finder), Nudges (break minutes plus toggle, distraction minutes plus toggle),
Sorting (Claude API key field saved to Keychain with an "In Keychain" chip, and a "Key
rejected" chip on a 401; Categories and rules row with the nine category chips and a Manage
button), Permissions (Accessibility, Chrome, Safari, Notifications, each with a status chip
and an Open System Settings button when not granted).

Copy change from the mockup: the rules row reads "9 categories, {N} rules. Change or remove
any rule." (categories are fixed in v1).

Manage opens a Rules sheet: search field, table of rules (kind, key, category picker, source
default/you/Claude), delete button per row. Deleting a default rule stores a tombstone so the
seed does not bring it back.

## 5. Architecture

Swift 6, SwiftUI plus AppKit, macOS 15 minimum, built with Swift Package Manager and the
command line tools only (no Xcode). Verified on this Mac: Swift 6.1.2, Swift Testing runs,
`import SQLite3` links, `MenuBarExtra` compiles.

Package targets:
- `TempoCore` (library): all logic with no AppKit. Models, segment building, rule matching,
  block building, day summary, nudge engine, SQLite store, Claude classifier, launch agent
  plist rendering. Everything takes an injected clock so tests are deterministic.
- `Tempo` (executable): the app. Activity monitor (NSWorkspace, Accessibility, AppleScript,
  idle and power checks), menu bar, windows, notifications, Keychain, permissions.
- `TempoCoreTests`: Swift Testing suite for `TempoCore`.

Units and boundaries:

| Unit | Job | Depends on |
|---|---|---|
| `Snapshot` | What is in front right now: bundle id, app name, window title, domain | nothing |
| `SegmentBuilder` | Turns ticks of snapshots plus idle state into segments | Snapshot, Clock |
| `Store` | SQLite reads and writes, migrations | SQLite3 |
| `RuleResolver` | Snapshot key to category id | rules from Store |
| `BlockBuilder` | Segments plus resolver to calendar blocks and away gaps | RuleResolver |
| `DaySummary` | Totals, longest stretch, distraction, week bars | BlockBuilder |
| `NudgeEngine` | Live state machine that decides when to fire | Clock |
| `ClassifierQueue` + `ClaudeClassifier` | Batch unknown keys to Claude, write rules | Store, URLSession |
| `ActivityMonitor` (app) | 5s tick, reads the system, feeds SegmentBuilder and NudgeEngine | AppKit, AX, AppleScript, IOKit |
| `TempoModel` (app) | Observable state for all views, recomputes on changes | all of the above |

## 6. Tracking

Tick every 5 seconds (timer tolerance 1s). Each tick:
1. If paused, locked, asleep, or the front app is `com.apple.loginwindow` or
   `com.apple.ScreenSaver.Engine`: treat as away.
2. Idle check: seconds since last input from
   `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)`.
   Idle means seconds since input is at least the threshold (default 300) and no display
   sleep prevention assertion is active (`IOPMCopyAssertionsStatus`,
   `PreventUserIdleDisplaySleep`). The assertion check keeps calls and playing video counted
   when nobody touches the keyboard.
3. Otherwise build a snapshot: front app via `NSWorkspace.shared.frontmostApplication`;
   window title via Accessibility (`kAXFocusedWindowAttribute` then `kAXTitleAttribute`,
   trimmed to 300 characters); for Chrome and Safari only, the active tab URL and title via
   `NSAppleScript`. Chrome windows in incognito mode record no title and no domain.
4. Domain normalization: lowercase host, drop a leading `www.`, keep the port only for
   `localhost`, `127.0.0.1`, and hosts ending `.localhost` or `.test`. Non-http schemes give
   no domain.

Segment rules (`SegmentBuilder`):
- A segment is one unbroken run of the same (bundle id, title, domain).
- A change at tick t closes the old segment at t and opens a new one at t.
- Going idle closes the segment at the last input time (now minus idle seconds), so idle
  minutes never count.
- Lock, sleep, pause, and screensaver close the segment at the event time.
- If the gap since the previous tick is over 30 seconds (missed ticks), the segment closes at
  the previous tick time.
- Segments under 1 second are dropped.

## 7. Storage and categorizing

### 7.1 Store
SQLite at `~/Library/Application Support/Tempo/tempo.db`, WAL mode. Timestamps are Unix
seconds (UTC); day math uses the current calendar and time zone, and segments crossing
midnight are clipped per day at read time.

```sql
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);           -- schema_version
CREATE TABLE segments(
  id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL,
  bundle_id TEXT NOT NULL, app_name TEXT NOT NULL, title TEXT, domain TEXT);
CREATE INDEX segments_start ON segments(start);
CREATE TABLE rules(
  kind TEXT NOT NULL CHECK(kind IN ('app','domain')), key TEXT NOT NULL,
  category_id TEXT, source TEXT NOT NULL CHECK(source IN ('default','user','claude')),
  updated_at REAL NOT NULL, PRIMARY KEY(kind, key));                    -- NULL category = tombstone
CREATE TABLE nudges(id INTEGER PRIMARY KEY, at REAL NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('break','distraction')));
CREATE TABLE classify_attempts(kind TEXT NOT NULL, key TEXT NOT NULL,
  last_try REAL NOT NULL, failures INTEGER NOT NULL, PRIMARY KEY(kind, key));
```

The open segment is inserted when it starts and its `end` is updated at least every 30
seconds and when it closes, so a crash loses under 30 seconds. Categories are not stored on
segments; they are resolved when a day is viewed, which is what lets one rule change re-sort
every day.

### 7.2 Rule matching (`RuleResolver`)
Item key: the domain when the segment has one, otherwise the app bundle id.
1. Domain segments: exact host rule, then each parent (`a.b.example.com`, `b.example.com`,
   `example.com`). First hit wins. No hit: Uncategorized (the browser's own app rule is not
   used, since it says nothing about the site).
2. App segments: the bundle id rule. No hit: Uncategorized.
3. A tombstone (NULL category) counts as no rule.

Writes: a user choice upserts `(kind, key)` with `source = user`. Claude and the seed only
insert where no row exists, so they never overwrite a user choice or a tombstone.

### 7.3 Default rules (seeded on first launch and on new seed versions, insert only)
- Code: Claude (`com.anthropic.claudefordesktop`), Terminal, VS Code, Antigravity and
  Antigravity IDE; github.com, gitlab.com, vercel.com.
- Design: CapCut, Freeform; figma.com, canva.com.
- Communication: Mail, Messages, Slack, WhatsApp, Contacts; mail.google.com,
  outlook.office.com, outlook.live.com, linkedin.com, slack.com.
- Meetings: zoom.us, Microsoft Teams, FaceTime, Fathom, Loom; meet.google.com,
  teams.microsoft.com, teams.live.com, zoom.us.
- Writing: Obsidian, Notes, TextEdit, Stickies; docs.google.com, notion.so.
- Research: Chrome and Safari (used only when no domain), Preview, Books, Dictionary;
  google.com, stackoverflow.com, wikipedia.org, developer.apple.com, cloudflare.com,
  developers.cloudflare.com, perplexity.ai, chatgpt.com.
- Admin: Finder, System Settings, Passwords, Calendar, Reminders, App Store, Logi Options+,
  Private Internet Access, SwiftBar, Tempo itself; dash.cloudflare.com, dashboard.stripe.com,
  stripe.com, calendly.com, calendar.google.com, drive.google.com, supabase.com.
- Distraction: TV, News, Stocks, Chess, Podcasts, Music, Spotify; youtube.com, x.com,
  twitter.com, reddit.com, instagram.com, facebook.com, tiktok.com, netflix.com, twitch.tv,
  espn.com, news.ycombinator.com.

The exact bundle ids live in `Sources/TempoCore/Resources/default-rules.json`.

### 7.4 Claude fallback (`ClassifierQueue`, `ClaudeClassifier`)
- Runs only when an API key is in Keychain (service `com.grantfeltz.tempo`, account
  `anthropic-api-key`).
- When a segment closes with an item key that has no rule and no backoff, the key is queued
  with its app name and one sample title.
- A worker flushes the queue at most once a minute, up to 20 keys per request, to the
  Messages API with model `claude-haiku-4-5`, a system prompt listing the eight assignable
  categories with one-line descriptions, and a JSON schema output of `{key, category}` pairs
  constrained to the eight ids.
- Answers are inserted as `source = claude` rules. Views refresh.
- Failures record `classify_attempts` and retry after 1 hour (doubling, max 24 hours). A 401
  marks the key rejected in Settings and pauses the worker until the key changes.
- Never sent: full URLs, paths, query strings, more than one title per key, times, durations.

## 8. Blocks and the day summary

`BlockBuilder` for one day:
1. Resolve each clipped segment to a category.
2. Build runs: consecutive segments of the same category join when the gap between them is
   60 seconds or less.
3. Fold: a run shorter than 120 seconds that sits between two runs of the same category
   (both gaps 60 seconds or less) merges the three into one block of the outer category.
   Its items keep their own category in the inspector.
4. Gaps between blocks of 5 minutes or more become away gaps.
5. Each block carries start, end, category, live flag (today and still open), and items
   aggregated by item key with durations.

`DaySummary`: total active time (sum of segment durations, not block spans), first activity,
longest stretch (longest block), distraction total, per-category totals, and week bars
(per-day, per-category totals for Mon to Sun).

## 9. Nudges (`NudgeEngine`)

Fed on every tick with (now, active or away, live category, live item names).
- Break: the active streak starts at the first activity after an away gap of 5 minutes or
  more (idle, lock, sleep, pause). When the streak reaches the break threshold (default 90
  minutes) it fires once. It re-arms only after the next 5 minute break.
- Distraction: a streak starts when the live category becomes Distraction and survives
  non-Distraction interruptions under 60 seconds. At the threshold (default 20 minutes) it
  fires once. It ends after 60 seconds of anything else or on away.
- Each fire writes a `nudges` row (for timeline markers) and posts the notification.
- Toggles and thresholds come from Settings. Pause stops both.

## 10. App lifecycle

- Bundle id `com.grantfeltz.tempo`, `LSUIElement` true (no Dock icon), fonts via
  `ATSApplicationFontsPath`, `NSAppleEventsUsageDescription` set.
- Single instance: on launch, if another Tempo process is running, activate it and exit 0.
- Launch at login: a LaunchAgent at `~/Library/LaunchAgents/com.grantfeltz.tempo.plist`
  running `/Applications/Tempo.app/Contents/MacOS/Tempo` with `RunAtLoad` true,
  `KeepAlive` `{SuccessfulExit: false}`, `ProcessType` Interactive, `ThrottleInterval` 10.
  A crash relaunches it; Quit exits 0 and it stays quit until next login. The Settings toggle
  writes or removes the plist and runs `launchctl bootstrap` or `bootout` for `gui/$UID`.
- First launch: seed rules, request Accessibility (prompting), request notification
  permission, open the timeline once.

## 11. Build, sign, install

- `swift build -c release`, then `scripts/build-app.sh` assembles `build/Tempo.app`
  (Info.plist, binary, fonts, icon, default rules).
- App icon: a small Swift script draws the three-blocks glyph at every size into an iconset;
  `iconutil` makes `AppIcon.icns`.
- Signing: `scripts/setup-signing.sh` creates a self-signed code signing identity
  "Tempo Dev" in the login keychain once (Grant enters his password to trust it). Signing
  with a stable identity keeps Accessibility and Automation grants across rebuilds.
  Fallback if that fails: ad-hoc signing, with Accessibility re-granted after each install.
- `scripts/install.sh`: build, assemble, sign, boot out the running agent, copy to
  `/Applications/Tempo.app`, write the LaunchAgent, bootstrap it.

## 12. Error handling

| Situation | Behavior |
|---|---|
| Accessibility not granted | Track apps without titles; status pill "Needs permission"; Settings shows Open System Settings |
| Automation denied for a browser | No domain for that browser; its app rule applies; Settings shows it |
| AppleScript slow or errors | 1 second timeout; snapshot without domain for that tick |
| Notifications denied | Nudges still logged and marked on the timeline |
| Database fails to open | Move it to `tempo.db.broken-<timestamp>`, start fresh, show a one-time alert |
| Disk write fails | Keep the open segment in memory, retry next flush, log to `~/Library/Logs/Tempo.log` |
| Claude errors or offline | Stay Uncategorized, back off per section 7.4 |
| Clock jump or missed ticks | Close at the previous tick (section 6) |

## 13. Testing

Swift Testing on `TempoCore` with a fake clock and an in-memory SQLite database:
- SegmentBuilder: joins, changes, idle trimming to last input, lock and sleep closes, missed
  tick gap, sub-second drop.
- Domain normalization and RuleResolver: parent matching, localhost port, tombstones, user
  over Claude over default precedence, browsers falling to Uncategorized.
- BlockBuilder: runs, 60 second joins, the 2 minute fold, away gaps, midnight clipping,
  live flag, item aggregation.
- DaySummary and week bars against the mockup's sample day (8h 41m, Code 4h 14m, and so on).
- NudgeEngine: break fires once at 90, re-arms after a 5 minute break; distraction survives
  a 45 second interruption, ends after 60 seconds, fires once.
- Store: migrations from empty, flush and update of the open segment, rule upsert rules,
  seed idempotence.
- ClaudeClassifier: request body shape and headers (stubbed `URLProtocol`), parsing, 401 and
  5xx paths, never sends URLs or paths.
- LaunchAgent plist rendering.

Manual checks on the real Mac (listed in the plan): permissions prompts, Chrome and Safari
domains, incognito skip, idle trimming during a real 6 minute break, a Teams call without
typing still counting, lock and sleep, nudges firing with short test thresholds, crash
restart via `kill -9`, Quit staying quit, login launch after a restart.

## 14. Risks

1. Self-signed identity trust needs Grant's password once; if `codesign` still refuses it,
   fall back to ad-hoc and re-grant Accessibility per install.
2. Background apps holding display sleep assertions (caffeinate-style tools) can stop idle
   from ever triggering. Lock and sleep still stop tracking.
3. `MenuBarExtra` window focus is quirky for `LSUIElement` apps; opening windows needs
   `NSApp.activate`.
4. Rize is also installed. Both can run at once; Tempo ignores Rize's own window like any
   other app.
