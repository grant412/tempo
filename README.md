# Tempo

Personal automatic time tracker for macOS. Lives in the menu bar, records the app, window, and
browser tab in front, sorts time into categories, and shows the day as a vertical calendar.
Nudges after long stretches and distraction streaks. Everything stays on this Mac except a
one-time Claude lookup for apps and sites it has never seen (only with an API key in Settings).

Design: `docs/superpowers/specs/2026-09-26-tempo-design.md`
Plan: `docs/superpowers/plans/2026-09-26-tempo.md`

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
  the site in the active tab.
- Notifications: allow them when asked, or break and distraction nudges never show.
- With ad-hoc signing (no "Tempo Dev" identity), macOS treats every build as a new app:
  re-grant Accessibility after every install.

## Privacy

Chrome incognito windows are not recorded (no title, no site). Safari Private windows and
private windows in other Chromium browsers (Arc, Brave, Edge) are not detected, so they are
recorded like any other window.

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
