# Tempo

Personal automatic time tracker for macOS (menu bar app). Native Swift: SwiftUI + AppKit, SwiftPM,
SQLite, Swift Testing. Built with the command line tools only; there is no Xcode project.

## Install or update

Follow README.md, "Install on a new Mac". Update with `git pull` then `scripts/install.sh`.
After an install, the person has to grant Accessibility (and Chrome and Safari control, if macOS
asks again) themselves in System Settings; Claude cannot click those dialogs.

## Working on the code

- Build and test only with `swift build` and `swift test`. Tests use Swift Testing, not XCTest.
- Pure logic lives in `Sources/TempoCore` with tests in `Tests/TempoCoreTests`; the app is `Sources/Tempo`.
- Specs and plans are in `docs/superpowers/` (dated). Read the matching spec before changing a feature.
- Never run AppleScript against the person's real Chrome or Safari to test blocking (it drives
  their browsers); use `osacompile` to check script syntax and the hands-on checklist in
  `docs/hands-on-checklist.md` for live checks.
- `Resources/Blocking/oisd-nsfw-small.txt` is a fixed snapshot; do not edit or re-download it.
  Adult blocking and SafeSearch have no switch on purpose (site blocking spec, section 1).
- No em dashes or en dashes in UI copy, comments, or docs.
