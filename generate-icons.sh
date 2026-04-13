#!/bin/bash
# Generates all app icon sizes from assets/AppIcon-source.png,
# applying macOS-style rounded corners so icons look correct on all OS versions.

SRC="assets/AppIcon-source.png"
DEST="YTGet/Assets.xcassets/AppIcon.appiconset"

if ! command -v magick &>/dev/null; then
  echo "ImageMagick not found. Install with: brew install imagemagick"
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "Source image not found: $SRC"
  exit 1
fi

# macOS icon corner radius is ~22.5% of icon size
SIZE=1024
RADIUS=230

echo "Applying rounded corners..."
TMP=$(mktemp /tmp/icon-rounded.XXXXXX.png)

# Create a rounded rectangle mask and apply it to the source
magick -size ${SIZE}x${SIZE} xc:none \
  -fill white \
  -draw "roundrectangle 0,0 $((SIZE-1)),$((SIZE-1)) $RADIUS,$RADIUS" \
  "$SRC" \
  -compose SrcIn -composite \
  "$TMP"

echo "Generating icon sizes..."
for size in 16 32 64 128 256 512 1024; do
  magick "$TMP" -resize ${size}x${size} "$DEST/icon_${size}x${size}.png"
  echo "  ${size}x${size}"
done

rm "$TMP"
echo "Done. Clean build in Xcode to apply changes."
