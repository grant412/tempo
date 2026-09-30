#!/bin/zsh
# Builds, installs to /Applications, writes the LaunchAgent, and starts Tempo under launchd.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
GUI="gui/$(id -u)"
launchctl bootout "$GUI/com.grantfeltz.tempo" 2>/dev/null || true
pkill -x Tempo 2>/dev/null || true
sleep 1
rm -rf /Applications/Tempo.app
cp -R build/Tempo.app /Applications/Tempo.app
/Applications/Tempo.app/Contents/MacOS/Tempo --write-launch-agent
launchctl bootstrap "$GUI" "$HOME/Library/LaunchAgents/com.grantfeltz.tempo.plist"
echo "installed and started"
echo "Next: in Accessibility, remove Tempo with the minus button, add /Applications/Tempo.app with"
echo "the plus button, and turn it on. Allow Chrome and Safari control if macOS asks."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
