#!/bin/zsh
# Builds release and assembles build/Tempo.app.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Tempo
APP=build/Tempo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" "$APP/Contents/Resources/Blocking"
cp .build/release/Tempo "$APP/Contents/MacOS/Tempo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/" 2>/dev/null || echo "warning: no fonts in Resources/Fonts"
cp Resources/Blocking/blocked.html Resources/Blocking/distraction.jpg Resources/Blocking/oisd-nsfw-small.txt \
  "$APP/Contents/Resources/Blocking/"
[[ -f build/AppIcon.icns ]] || swift scripts/make-icon.swift build
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Ad-hoc: no certificate and no keychain prompts. macOS treats each build as a new app, so
# Accessibility is removed and re-added after every install.
codesign --force --sign - --identifier com.grantfeltz.tempo "$APP"
codesign --verify --verbose "$APP"
echo "built $APP"
