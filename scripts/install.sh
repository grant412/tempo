#!/bin/zsh
# Builds, installs to /Applications, writes the LaunchAgent, and starts Tempo under launchd.
# Makes the "Tempo Dev" signing identity first if this Mac does not have it yet.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/setup-signing.sh
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
