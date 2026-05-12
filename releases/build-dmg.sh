#!/bin/bash
# Usage: ./build-dmg.sh /path/to/YTGet.app
# Builds a distributable DMG, signs it for Sparkle, and updates appcast.xml.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP=$1

if [ -z "$APP" ]; then
  echo "Usage: $0 /path/to/YTGet.app"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
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

# Sign the DMG and update appcast.xml
SIGN_UPDATE="${SCRIPT_DIR}/sign_update"
APPCAST="${REPO_ROOT}/appcast.xml"

if [ ! -f "$SIGN_UPDATE" ]; then
  echo "⚠️  sign_update not found — skipping Sparkle signature."
  exit 0
fi

echo ""
echo "Signing DMG for Sparkle..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$OUTPUT")

# Extract edSignature from sign_update output
ED_SIG=$(echo "$SIGN_OUTPUT" | grep -o 'edSignature="[^"]*"' | sed 's/edSignature="//' | tr -d '"')
DMG_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DMG_URL="https://github.com/leaskc/YTGet/releases/download/v${VERSION}/YTGet-${VERSION}.dmg"

# Insert new <item> before the first existing one using Python (BSD sed
# can't handle multi-line replacement strings reliably on macOS).
# The <description> CDATA block is what Sparkle shows in the update dialog —
# edit it in appcast.xml before pushing to add proper release notes.
python3 - <<PYEOF
appcast = open("${APPCAST}").read()

new_item = """    <item>
      <title>YTGet ${VERSION}</title>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[
        <h3>YTGet ${VERSION}</h3>
        <ul>
          <li><!-- add release notes here before pushing --></li>
        </ul>
      ]]></description>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url="${DMG_URL}"
        sparkle:edSignature="${ED_SIG}"
        length="${DMG_SIZE}"
        type="application/octet-stream"
      />
    </item>"""

updated = appcast.replace("    <item>", new_item + "\n\n    <item>", 1)
open("${APPCAST}", "w").write(updated)
PYEOF

echo "✅ appcast.xml updated for v${VERSION} (build ${BUILD})"
echo ""
echo "Next steps:"
echo "  1. Edit appcast.xml — fill in the release notes in the <description> block"
echo "  2. git add appcast.xml && git commit -m 'Release ${VERSION}' && git push"
echo "  3. gh release create v${VERSION} '${OUTPUT}' --title 'YTGet ${VERSION}'"
