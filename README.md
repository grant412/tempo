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
    scripts/fetch-fonts.sh     # once: downloads the OFL fonts
    scripts/install.sh         # build, sign, install to /Applications, start at login

## Where things live

- Data: `~/Library/Application Support/Tempo/tempo.db` (SQLite)
- Log: `~/Library/Logs/Tempo.log`
- Launch agent: `~/Library/LaunchAgents/com.grantfeltz.tempo.plist`
- API key: login Keychain, service `com.grantfeltz.tempo`

## Uninstall

    launchctl bootout gui/$(id -u)/com.grantfeltz.tempo
    rm -rf /Applications/Tempo.app ~/Library/LaunchAgents/com.grantfeltz.tempo.plist

Data stays in Application Support until you delete that folder yourself.
