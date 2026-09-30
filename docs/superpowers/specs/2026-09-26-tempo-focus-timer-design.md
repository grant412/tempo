# Tempo: Stop tracking and focus timer (design)

Date: 2026-09-26
Status: implemented on tempo-focus-timer, live checks pending
Builds on: `2026-09-26-tempo-design.md` (sections 4.1 menu bar, 4.2 timeline, 7.1 store)
Branch: `tempo-focus-timer`, off `tempo-v1`

## 1. Summary

Two additions to the menu bar dropdown:

1. **Stop tracking.** A pause with no end time. Tracking stays off until Grant presses Resume.
   It is not saved, so any relaunch (login, reboot, crash restart) starts tracking again.
2. **Focus timer.** A countdown Grant starts for a focus session or to time a block of work.
   Tracking keeps running underneath it. While it runs, the menu bar shows a clock and the
   time left. When it ends, Tempo plays a short chime and a pop-up slides into the top right
   corner with a summary of what Tempo tracked in those minutes and "What did you get done?"
   (changed 2026-09-30 from a notification, see 3.3). Every finished session is saved and
   drawn on the timeline as a band, with its note.

## 2. Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Stop across relaunch | Not saved. A relaunch tracks again, same as the timed pauses. |
| What the timer does | Separate countdown. Tracking runs normally while it counts. |
| Presets | 5 min, 15 min, 30 min, 1 hour, 2 hours, Custom (minutes). |
| How presets open | Hovering the "Start a timer" row opens a popover beside it (click also opens it). Custom popover drawn in Tempo's style, not a native NSMenu. |
| Menu bar while running | Clock icon and time left after today's total: `[glyph] 3h 12m  (clock) 24:13`. |
| When the timer runs out | Tempo plays the macOS "Glass" chime and shows the pop-up in the top right corner (2026-09-30; was a notification). |
| Where notes are typed | The pop-up: session summary on top, then "What did you get done?" with the notes box open, Save and Skip. |
| Timeline | Each session is a band on the day view. Hover shows the note, click opens the pop-up. |
| When a session is saved | At the end (run out or End now). A running timer lives in memory only; quitting or a crash mid-timer drops it. Grant accepted this. |

## 3. Screens

### 3.1 Dropdown

Order, top to bottom (new parts marked):

```
TODAY SO FAR
3h 12m
[live block card]
[category bars]

FOCUS TIMER                                   new
[ (clock)  Start a timer                 > ]  new: hover opens the preset popover

PAUSE TRACKING
[ 30 min ] [ 1 hour ] [ Until tomorrow ]
[            Stop tracking             ]      new

[ Open timeline ]
Settings                       Quit Tempo
```

**Focus timer, idle.** One full-width row, 40 pt tall, with the `SmallButton` border and corner radius:
clock symbol, "Start a timer", chevron at the right. Hovering the row opens the popover;
clicking it does too (keyboard and accessibility path). The popover opens on the row's leading
side and flips if there is no room.

**Preset popover** (white panel, Theme fonts, about 220 pt wide):

```
START A TIMER
5 min
15 min
30 min
1 hour
2 hours
-----------------------
Custom  [ 45 ] min  [Start]
```

Each preset row highlights on hover (chip fill) and starts the timer on click. The Custom field
takes whole minutes, 1 to 600; Return or Start begins the timer. Anything else leaves the
Start button disabled. Picking a time closes the popover. Clicking outside closes it too.

**Focus timer, running.** The row is replaced by:

```
FOCUS TIMER
(clock) 24:13 left                 [End now] [Discard]
25 min, started 2:10 PM
```

The countdown is Geist Mono with monospaced digits and updates every second.

- **End now** saves the session with the actual end time and opens the pop-up right away,
  ready to type in (no chime, Grant is already looking at Tempo).
- **Discard** drops the timer. Nothing is saved.

Only one timer runs at a time. Stopping or pausing tracking does not touch a running timer.

**Pause tracking.** The existing row stays. Under it, a full-width **Stop tracking** button
(`SmallButton` style, not filled). States:

| State | Row shows |
|---|---|
| Tracking | the three timed chips, then Stop tracking |
| Timed pause | "Paused until 3:15 PM" and Resume (unchanged) |
| Stopped | "Tracking stopped" and Resume |

The live block card already hides while paused, so it hides while stopped too.

### 3.2 Menu bar item

| State | Label |
|---|---|
| Tracking | `[glyph] 1:09 · 3h 12m`, time at the keyboard then today's total (main spec 4.1, changed 2026-09-30) |
| Timed pause | `[glyph] Paused` (unchanged) |
| Stopped | `[glyph] Stopped` |
| Any of the above with a timer running | the same, then two spaces, the `timer` SF Symbol, and the time left, e.g. `[glyph] 3h 12m  (clock) 24:13` |

Time left format: `m:ss` under an hour (`24:13`, `5:00`, `0:07`), `h:mm:ss` from an hour up
(`1:59:12`). It counts up to the next whole second, so a new 25 minute timer reads `25:00` and
the last second reads `0:01`. Digits are monospaced so the item does not jitter.

The label is built as one `Text` with the SF Symbol interpolated
(`Text("\(total)  \(Image(systemName: "timer")) \(left)")`), because a `MenuBarExtra` label is
not guaranteed to lay out more than one image and one text.

### 3.3 Timer done (changed 2026-09-30)

When a running timer reaches its end (the 1 s tick sees `now >= end`), Tempo saves the
session, plays the macOS "Glass" sound itself (`NSSound`, one short ching), and shows the
pop-up (3.4). Tempo plays the sound, so notification settings and Focus modes cannot mute it.
If the Mac was asleep at that moment, both happen on wake and the session still ends at the
planned end.

This replaced the "Timer done" notification after Grant's first live test: the banner was
easy to miss, played no sound, and hid its "Write down what you got done" button until
hovered. No timer notification is posted now. Clicking an old one still in Notification
Center opens that session's pop-up.

### 3.4 Pop-up

A floating panel (`WindowManager.showFocusNotes`), 400 pt wide and as tall as its content,
16 pt in from the top right corner of the screen under the pointer, modeled on Rize's
"focus session ended" panel. It floats over every app and Space, including full screen. It
slides in from the right. On End now or a timeline click it stays until closed; on run-out it
closes itself (below). On run-out it does not take focus from the
app in front, so typing elsewhere never lands in the notes box; a click on it makes it key.
End now and a timeline click make it key right away. Light or dark with the rest of the app.
One pop-up at a time: opening it for another session replaces the content; opening it again
for the session it shows only brings it forward, so a draft survives.

```
(timer) FOCUS TIMER                                    [x]
Your focus timer is done.                  (Bricolage 24; "Your focus session" from the timeline)
3:18 PM to 3:23 PM, 5 min                  (muted; "18 min of 25 min" when ended early)
-----------------------------------------------------------
4m               97%               0m
at the keyboard  of the session    distraction
TOP CATEGORIES
[top 3 category bars, same CategoryBarRow as the dropdown]
mail.google.com, n8n.io, docs.google.com   (top 3 apps or sites, muted)
-----------------------------------------------------------
What did you get done?
[ notes box, 96 pt, open and empty ]
                                              [Skip] [Save]
```

- The summary is built from the segments that overlap the session, clipped to it. "Of the
  session" is time at the keyboard over the session's length. If nothing was tracked, the
  summary reads "Nothing tracked in this session."
- The notes box is prefilled with the saved note when reopening a session.
- **Save** (Cmd+Return) stores the trimmed note (empty text stores no note) and closes.
- **Skip** and the x close without changing the note.
- **Auto close on run-out (added 2026-09-30).** Once it has slid in, a 3 pt ink bar along the
  bottom edge shrinks from the right to the left over 5 s. If the pointer never comes over the
  pop-up, it slides back out to the right when the bar runs out, the same as Skip: the session
  stays saved with no note and can be reopened from the timeline. The pointer coming over it
  (an AppKit tracking area, so it works while another app is in front), a pointer already over
  it when the bar would start, or a click during the slide-in stops the countdown for good; the
  bar fades and the pop-up stays until Save, Skip, or the x. End now and a timeline click never
  count down.

### 3.5 Timeline band

Each saved session overlapping the shown day draws on `DayCanvas`:

- A 3 pt ink bar in the gutter just left of the block column (around x 58 to 61), from the
  session's start to its end, clamped to the visible range.
- A 16 pt ink circle with a white `timer` symbol centered on the bar's top.
- Hover (`.help`): the note, or "Focus timer, 25 min, no notes yet".
- Click: opens the pop-up for that session.
- The legend next to "nudge sent" gains a "focus timer" key with the same badge.

The toolbar status pill reads "Stopped" (muted dot) while stopped. The toolbar's Pause menu is
unchanged.

## 4. Architecture

### 4.1 TempoCore (pure, unit tested)

- `FocusTimer.swift`
  - `struct FocusTimer: Equatable, Sendable { start: Date; planned: TimeInterval }` with
    `end`, `remaining(at:)` (never negative), `isDone(at:)`.
  - `static let presets: [TimeInterval] = [300, 900, 1800, 3600, 7200]`.
  - `static func customMinutes(_ text: String) -> Int?`: trimmed whole number 1...600, else nil.
- `Models.swift`: `struct FocusSession: Equatable, Identifiable, Sendable { id: Int64; start;
  end; planned: TimeInterval; note: String? }` with `duration` and `endedEarly`
  (actual duration at least 1 s short of planned).
- `Format.swift`: `countdown(_ seconds:)` per 3.2 (ceil to whole seconds), and
  `minutesLabel(_ seconds:)` for `25 min` / `1 hour` / `2 hours` / `1h 30m`.
- `Summaries.swift`: `struct SessionRecap { total; categories: [CategoryTotal]; topNames:
  [String] }` with `static func make(segments:interval:resolver:)`. Categories reuse the
  `DaySummary.make` ordering; top names reuse `BlockBuilder.items(for:)`.
- `Store.swift`: schema version 2 adds

  ```sql
  CREATE TABLE focus_sessions(
    id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL,
    planned REAL NOT NULL, note TEXT);
  CREATE INDEX focus_sessions_start ON focus_sessions(start);
  ```

  in its own `version < 2` transaction, so a v1 database upgrades in place with its data.
  Methods: `insertFocusSession(start:end:planned:) -> Int64`, `setFocusNote(id:note:)`
  (whitespace-only or empty stores NULL), `focusSession(id:) -> FocusSession?`,
  `focusSessions(overlapping:) -> [FocusSession]` ordered by start.

### 4.2 Tempo app

- `TempoModel`
  - `stop()` sets `pausedUntil = .distantFuture`; `isStopped` is `pausedUntil == .distantFuture`.
    Everything else (away presence, segment close, nudges off, Resume) already follows
    `pausedUntil`. `menuBarText` returns "Stopped" when stopped.
  - `@Published focusSessions: [FocusSession]` for the shown day, loaded in `refresh()`
    next to `nudgeMarks`.
  - `saveFocusSession(_ timer: FocusTimer, end: Date) -> FocusSession?`,
    `setFocusNote(id:note:)`, `focusSession(id:)`, `recap(for:) -> SessionRecap` (uses
    `withLive` so the open segment counts).
- `FocusController` (new, `@MainActor ObservableObject`, shared): `@Published timer`,
  `@Published now`. Owns a 1 s `Timer` (tolerance 0.1, `.common` run loop mode) that runs
  only while a timer is active, so the rest of the app is not redrawn every second.
  `start(seconds:)`, `endNow()`, `discard()`. On each tick, if done: save the session with
  `end = timer.end`, clear, play the chime, show the pop-up without focus. `endNow()` saves
  with `end = now` and shows the pop-up with focus.
- `Notifier`: posts no timer notifications (since 2026-09-30). `didReceive` still routes an
  old `timer-done` notification to `WindowManager.showFocusNotes(sessionID:)`; everything
  else keeps opening the timeline.
- `WindowManager.showFocusNotes(sessionID:justEnded:activate:)`: one floating pop-up panel
  (3.4); replaces its root view each time it is shown for another session.
- Views: `Views/FocusTimerSection.swift` (idle row, popover, running row),
  `Views/FocusNotesView.swift`, `MenuBarLabel` (single `Text`), `PauseSection` (Stop),
  `DayCanvas` (band and legend), `StatusPill` (Stopped).

## 5. Error handling

- Store writes that fail are logged (`Log.error`) like every other write. A failed session
  insert means no chime and no pop-up; the timer still clears.
- Notes window opened for an id that no longer exists shows "This session could not be
  found." with a Close button.
- Custom minutes outside 1 to 600 or not a whole number: Start stays disabled.

## 6. Testing

Unit (Swift Testing, `Tests/TempoCoreTests`):

- `FocusTimerTests`: remaining clamps at 0, `isDone` at and after end, presets, custom parsing
  (`"45"`, `" 45 "`, `"0"`, `"601"`, `"4.5"`, `"abc"`, `""`).
- `FormatTests`: countdown `25:00`, `5:00`, `0:07`, `0:01` for 0.2 s, `0:00` for 0, `1:00:00`,
  `1:59:12`; minutes labels.
- `StoreTests`: fresh database is schema 2; a hand-built v1 file upgrades to 2 and keeps its
  segments; session insert, note set, blank note stores nil, overlap query.
- `SummariesTests`: recap clips segments to the session, orders categories, top 3 names, empty.

Manual (added to `docs/hands-on-checklist.md` under "Stop tracking and focus timer"): stop and
resume, hover popover, each preset, custom, menu bar countdown, End now, Discard, run out with
the Mac awake (chime and pop-up), notes save and reopen, timeline band hover and click,
relaunch while stopped tracks again.

## 7. Out of scope

- Saving a running timer across quit or crash.
- Pausing a timer, repeating timers, Pomodoro cycles, a choice of chime sounds.
- Stats or reports over focus sessions beyond the timeline band.
- Starting a timer from the timeline window.
