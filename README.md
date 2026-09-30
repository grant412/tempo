# Tempo

Personal automatic time tracker for macOS. Lives in the menu bar, records the app, window, and
browser tab in front, sorts time into categories, and shows the day as a vertical calendar.
Nudges after long stretches and distraction streaks. Everything stays on this Mac except a
one-time Claude lookup for apps and sites it has never seen (only with an API key in Settings).

Design: `docs/superpowers/specs/2026-09-26-tempo-design.md`, plus
`docs/superpowers/specs/2026-09-26-tempo-focus-timer-design.md` (Stop tracking and focus timer) and
`docs/superpowers/specs/2026-09-30-tempo-site-blocking-design.md` (site blocking)
Plans: `docs/superpowers/plans/2026-09-26-tempo.md`, `docs/superpowers/plans/2026-09-26-tempo-focus-timer.md`,
`docs/superpowers/plans/2026-09-30-tempo-site-blocking.md`

## Build and install

    swift test                 # logic tests (Swift Testing)
    scripts/setup-signing.sh   # once: creates the "Tempo Dev" signing identity
    scripts/install.sh         # build, sign, install to /Applications, start at login

The fonts (OFL) are already committed in `Resources/Fonts`. Run `scripts/fetch-fonts.sh` only
if that folder is missing.

If you quit Tempo and then reopen it from Finder, it runs outside launchd, so it is not
relaunched after a crash until your next login. To put it back under launchd sooner, quit it
and run `launchctl kickstart gui/$(id -u)/com.grantfeltz.tempo`.

## Permissions

- Accessibility: grant it in System Settings, Privacy and Security, Accessibility, after
  install. Without it Tempo still tracks apps, but it cannot read window titles.
- Automation: approve Tempo controlling Chrome and Safari when macOS asks. That is how it reads
  the site in the active tab, and how it swaps in the blocked page.
- Notifications: allow them when asked, or break and distraction nudges never show.
- With ad-hoc signing (no "Tempo Dev" identity), macOS treats every build as a new app:
  re-grant Accessibility after every install.

## Blocking

- Adult sites are always blocked in Chrome and Safari, including incognito and private windows.
  The list is a fixed snapshot of OISD's NSFW small list (21,192 sites, 2026-09-30) in
  `Resources/Blocking/`, plus any site with porn, xxx, or hentai in its name. There is no switch.
- SafeSearch is always forced on Google, Bing, and DuckDuckGo.
- Distraction sites are blocked during one weekly window set in Settings, Blocking. While it runs,
  the schedule is locked and no site can be moved out of Distraction. Schedule changes apply when
  you press Save, and a change that starts the block right away asks first. The same start and
  end time runs 24 hours, so back-to-back days join into one block; Save names its real end first.
- Tempo checks the front tab every second and every tab every 5 seconds, and swaps a blocked tab
  for its own blocked page. Blocking keeps running when tracking is paused or stopped. Quitting
  Tempo turns it off.

## Privacy

Chrome incognito windows, and adult sites in Chrome and Safari, are not recorded (no title, no
site). Blocking reads every tab, incognito and private ones included, but never stores what it
reads. Safari Private windows are not detected for tracking, so they are recorded like any other
window. Other browsers (Arc, Brave, Edge, Firefox) are not read or blocked: their window titles
are recorded, private windows and adult pages included.

## Where things live

- Data: `~/Library/Application Support/Tempo/tempo.db` (SQLite)
- Log: `~/Library/Logs/Tempo.log`
- Launch agent: `~/Library/LaunchAgents/com.grantfeltz.tempo.plist`
- API key: login Keychain, service `com.grantfeltz.tempo`

## Uninstall

    launchctl bootout gui/$(id -u)/com.grantfeltz.tempo
    rm -rf /Applications/Tempo.app ~/Library/LaunchAgents/com.grantfeltz.tempo.plist
    security delete-generic-password -s com.grantfeltz.tempo -a anthropic-api-key

Data stays in Application Support until you delete that folder yourself.
