#!/bin/bash
# Usage: ./build-dmg.sh /path/to/YTGet.app
# Builds a distributable DMG and signs it for Sparkle auto-updates.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP=$1

if [ -z "$APP" ]; then
  echo "Usage: $0 /path/to/YTGet.app"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUTPUT="${SCRIPT_DIR}/YTGet-${VERSION}.dmg"

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

# Sign the DMG for Sparkle
SIGN_UPDATE="${SCRIPT_DIR}/sign_update"
if [ -f "$SIGN_UPDATE" ]; then
  echo ""
  echo "Signing DMG for Sparkle..."
  SIGNATURE=$("$SIGN_UPDATE" "$OUTPUT")
  echo ""
  echo "✅ Done. Add this to appcast.xml for v${VERSION}:"
  echo ""
  echo "  <enclosure"
  echo "    url=\"https://github.com/leaskc/YTGet/releases/download/v${VERSION}/YTGet-${VERSION}.dmg\""
  echo "    $SIGNATURE"
  echo "    length=\"$(wc -c < "$OUTPUT" | tr -d ' ')\""
  echo "    type=\"application/octet-stream\""
  echo "  />"
else
  echo "⚠️  sign_update not found — skipping Sparkle signature."
fi
