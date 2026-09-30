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
cp Resources/Blocking/blocked.html Resources/Blocking/oisd-nsfw-small.txt "$APP/Contents/Resources/Blocking/"
[[ -f build/AppIcon.icns ]] || swift scripts/make-icon.swift build
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="${TEMPO_SIGN_IDENTITY:-Tempo Dev}"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" --identifier com.grantfeltz.tempo "$APP"
else
  echo "warning: '$IDENTITY' not found, signing ad-hoc (re-grant Accessibility after each install)"
  codesign --force --sign - --identifier com.grantfeltz.tempo "$APP"
fi
codesign --verify --verbose "$APP"
echo "built $APP"
