# Tempo hands-on checklist

Everything here needs Grant at the Mac. The build never installed, signed, or launched the app,
so none of this has run on the real machine yet. Work top to bottom; the setup steps unlock the rest.

## Setup (one time)

- [ ] **Signing identity.** `scripts/setup-signing.sh`. A keychain dialog appears; click Always Allow.
      If it fails, skip it: install falls back to ad-hoc signing, and you re-grant Accessibility after every install.
- [ ] **Install.** `scripts/install.sh`. The first codesign may show a keychain dialog; click Always Allow.
      If it prints "Bootstrap failed: 5", run it again or `launchctl kickstart gui/$(id -u)/com.grantfeltz.tempo`.
- [ ] **Accessibility.** System Settings, Privacy and Security, Accessibility: turn Tempo on.
- [ ] **Notifications.** Allow Tempo's notifications when asked.
- [ ] **Browsers.** Use Chrome for a minute and approve "Tempo wants to control Google Chrome". Same for Safari when you use it.
      While that first prompt is up, note whether the menu bar item freezes.

## Menu bar and windows

- [ ] Menu bar shows the three-blocks glyph and today's total.
- [ ] Popover matches the "Menu bar" artboard (canvas page Calendar). Check its edges with macOS in dark mode too.
- [ ] Pause 30 min: menu bar reads "Paused", the row shows "Paused until ..." with Resume. Resume works.
- [ ] Open dashboard and Settings each open their window (and the popover closes).
- [ ] Timeline matches the renders. Visual call: traffic lights sit about 12 pt above the toolbar's center.
- [ ] Drag on blank toolbar space moves the window; double-click zooms.
- [ ] Blocks are clickable (ring moves), hover shows tooltips.
- [ ] It opens scrolled to now. Scroll away, close, reopen later: it re-centers on now.

## Dark mode and the keyboard line

- [ ] The sun and moon pill sits at the top right of the menu, beside "Today so far", and the menu is no taller than before.
- [ ] Click it: the menu, dashboard, Settings, Rules, focus notes, and the timer popover all turn dark at once, title bars and popover arrow included. Click again: all light.
- [ ] Quit and relaunch in dark: it opens dark. Settings switches that are on read clearly (white knob on gray-brown).
- [ ] Block labels stay readable in dark (ink on the light fills, white on Code, Research, Admin).
- [ ] Back from a break of 15 minutes or more: the menu and the dashboard's Today card read "at the keyboard since (time you came back), after (break) away".
- [ ] A 10 minute break does not restart the line.
- [ ] Menu bar reads like Rize without the seconds, "1:09 · 4h 20m": the first time matches "at the keyboard since" in the menu (now minus that time), the second is today's total.
- [ ] Away 15 minutes or more: the menu bar shows only the total. Back at the keyboard: it restarts at "0:00 · (total)". Paused and Stopped still read "Paused" and "Stopped".

## Tracking accuracy

- [ ] Rows look right after a few minutes of Terminal and Chrome:
      `sqlite3 ~/Library/Application\ Support/Tempo/tempo.db "select datetime(start,'unixepoch','localtime'), round(end-start), app_name, domain, substr(title,1,40) from segments order by id desc limit 10;"`
- [ ] Chrome incognito window for 30 s: its rows have no title and no domain.
- [ ] Decide: Safari Private windows and other Chromium browsers' private windows are NOT detected (their sites and titles are recorded).
- [ ] Idle: 6 minutes with no input and no video. The Away gap starts when input stopped.
- [ ] Calls: a Zoom or Teams call over 6 minutes with no typing still counts as Meetings after it ends.
- [ ] Lock (Ctrl+Cmd+Q) for 6+ minutes and sleep for 6+ minutes: both show as Away (gaps under 5 minutes join the blocks).
- [ ] App Nap: Activity Monitor's App Nap column shows "No" for Tempo; 30 minutes with every Tempo window closed shows one continuous block.

## Recategorizing

- [ ] Click a block and change Terminal to Writing: every Terminal block recolors, including yesterday. Change it back.
- [ ] Visit a localhost dev server for over a minute: the Needs a category panel shows it with a striped swatch. Tag it with a chip.
- [ ] An uncategorized block's rows show readable names and "Pick one" pickers.

## Nudges

- [ ] Short thresholds:
      `defaults write com.grantfeltz.tempo breakMinutes -int 1 && defaults write com.grantfeltz.tempo distractionMinutes -int 1 && launchctl kickstart -k gui/$(id -u)/com.grantfeltz.tempo`
- [ ] Work 70 s: one "Time for a break" banner. YouTube for 70 s: one "1 minutes on Distraction" banner.
- [ ] Bell badges appear on the timeline; clicking a banner opens today's timeline.
- [ ] Quit Tempo, then click an old nudge in Notification Center: it launches Tempo to today's timeline.
- [ ] Restore: `defaults delete com.grantfeltz.tempo breakMinutes; defaults delete com.grantfeltz.tempo distractionMinutes; launchctl kickstart -k gui/$(id -u)/com.grantfeltz.tempo`
- [ ] After an overnight sleep, no break nudge fires on wake.

## Claude sorting

- [ ] Settings: paste an API key, Save: "In Keychain" appears.
- [ ] Visit two sites Tempo has never seen for over a minute each. Within about two minutes `~/Library/Logs/Tempo.log` shows "classified N of M", and the Rules sheet lists them with source "Claude".
- [ ] Save a wrong key: "Key rejected" appears and the log says the key was rejected. Save the real key: back to "In Keychain".

## Settings and lifecycle

- [ ] Idle minutes and nudge thresholds apply without a restart.
- [ ] Open at login off removes `~/Library/LaunchAgents/com.grantfeltz.tempo.plist`; on writes it back.
- [ ] Rules sheet: search filters; changing a category re-sorts; deleting a default rule stays deleted after `scripts/install.sh`.
- [ ] Crash restart: `kill -9 $(pgrep -x Tempo)`, then within 15 s a new pid. Quit from the menu stays quit. `launchctl kickstart gui/$(id -u)/com.grantfeltz.tempo` brings it back.
- [ ] Optional: restart the Mac; Tempo is in the menu bar after login.
- [ ] Leave it running past midnight: the timeline rolls to the new day and yesterday is intact.

## Stop tracking and focus timer

Spec: `docs/superpowers/specs/2026-09-26-tempo-focus-timer-design.md`.

- [ ] Stop tracking: menu bar reads "Stopped", the row reads "Tracking stopped" with Resume, the toolbar pill says Stopped. No new segments while stopped. Resume tracks again.
- [ ] Stop, then quit and relaunch: Tempo tracks again.
- [ ] Hover "Start a timer": the popover opens beside it after a moment. Passing quickly over the row does not open it. Clicking outside closes it.
- [ ] Each preset starts the right length. Custom: 45 works; 0, 601, 4.5, and letters keep Start disabled; Return starts it.
- [ ] Menu bar shows the total, then the clock and time left, ticking every second without jitter. Over an hour shows h:mm:ss.
- [ ] Stopping or pausing tracking leaves a running timer counting.
- [ ] End now: the pop-up slides into the top right corner with the summary and "N min of M", ready to type. Save stores the note.
- [ ] Discard: nothing appears on the timeline.
- [ ] Let a 5 min timer run out while typing in another app: one "Glass" ching, and the pop-up slides into the top right corner with the summary and "What did you get done?". Your typing stays in the other app until you click the pop-up. No notification banner.
- [ ] The pop-up floats over a full screen app and on every Space. After End now or a timeline click it stays until Skip, Save, or the x.
- [ ] Run-out, pointer kept away: a thin bar along the bottom of the pop-up shrinks from right to left over 5 seconds, then the pop-up slides out to the right. The band is on the timeline with no note; clicking it reopens the pop-up with no bar.
- [ ] Run-out, pointer moved over the pop-up before the bar ends: the bar fades and the pop-up stays, even after moving the pointer away again.
- [ ] Run-out with the pointer already sitting in the top right corner: no bar, the pop-up stays.
- [ ] Timeline: the band spans the session with a clock badge. Hover shows the note. Click opens the pop-up with the note filled in.
- [ ] Sleep through a run-out: the ching and the pop-up come on wake and the session ends at the planned end.
- [ ] A timer run while tracking is stopped, outside the usual hours, still shows its band on the timeline.
- [ ] Custom field inside the popover takes typing and Return.

## Site blocking

- [ ] After install, re-grant Accessibility, then approve "Tempo wants to control Google Chrome" and the Safari prompt if they appear again.
- [ ] Settings, Blocking: the adult row shows "21,192 SITES". The Distraction row shows Mon to Fri, 9:00 AM to 5:00 PM, switched off.
- [ ] Adult: open a known adult site in a normal Chrome tab, a Chrome incognito window, and a Safari private window. Each is replaced by "This site is blocked." within about a second.
- [ ] Adult privacy: afterwards, the segments query from "Tracking accuracy" shows no adult domain or title, grepping the log for the adult test domain you used (`grep -i <domain> ~/Library/Logs/Tempo.log`) prints nothing, and the log has "blocked an adult site" lines.
- [ ] SafeSearch: a Google image search, a Bing search, and a DuckDuckGo search each reload once with safe=active, adlt=strict, or kp=1 in the address.
- [ ] Staged edits: set hours that do not cover now, switch the block on, and press Save (no alert). Then step the From time past the To time without pressing Save. Nothing locks. Press Cancel and the old hours come back. Then make a change that covers now and press Save: the "Start the Distraction block now?" alert appears, and Cancel leaves everything unlocked.
- [ ] Chained hours: set Mon to Fri, 9:00 AM to 9:00 AM. The detail line says back-to-back days join into one block. Press Save on any day: an alert names the real block (for example "from 9:00 AM until Saturday at 9:00 AM"), either "Start the Distraction block now?" or "Your hours join into one block". Press Cancel. Set all seven days to 12:00 AM to 12:00 AM: Save refuses with "This schedule never ends". Press Cancel to drop the draft.
- [ ] Distraction: set the window to start a minute from now, switch it on, and press Save. When it starts, an open YouTube tab (front and background) is replaced within 5 seconds with "youtube.com is blocked until <day> at <time>." (always a day name, never "tomorrow"). Back from the blocked page is replaced again.
- [ ] Lock: during the window the switch, days, and times are disabled with "Locked until ...". In Rules, youtube.com shows the lock badge; github.com can still be moved to Distraction. In the timeline inspector, a Distraction site shows the lock badge.
- [ ] The menu shows "Blocking Distraction until ..." during the window and nothing after it.
- [ ] Outside the window, YouTube loads normally and every control is editable.
- [ ] Stop tracking: blocking still works while tracking is stopped.
