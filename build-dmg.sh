#!/bin/bash
# Usage: ./build-dmg.sh /path/to/YTGet.app

APP=$1
if [ -z "$APP" ]; then
  echo "Usage: $0 /path/to/YTGet.app"
  exit 1
fi

VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
OUTPUT="YTGet-${VERSION}.dmg"

rm -f "$OUTPUT"

create-dmg \
  --volname "YTGet" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "YTGet.app" 140 190 \
  --app-drop-link 400 190 \
  --hide-extension "YTGet.app" \
  "$OUTPUT" \
  "$APP"

echo "Created: $OUTPUT"
