#!/bin/bash
set -euo pipefail

SET_DIR="ios/LastCall/Assets.xcassets/AppIcon.appiconset"
SOURCE="$SET_DIR/IMG_2392.png"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source icon: $SOURCE"
  exit 1
fi

# Generate the exact iPhone icon pixel sizes from the original LAST CALL master.
sips -z 40 40 "$SOURCE" --out "$SET_DIR/AppIcon-20@2x.png" >/dev/null
sips -z 60 60 "$SOURCE" --out "$SET_DIR/AppIcon-20@3x.png" >/dev/null
sips -z 58 58 "$SOURCE" --out "$SET_DIR/AppIcon-29@2x.png" >/dev/null
sips -z 87 87 "$SOURCE" --out "$SET_DIR/AppIcon-29@3x.png" >/dev/null
sips -z 80 80 "$SOURCE" --out "$SET_DIR/AppIcon-40@2x.png" >/dev/null
sips -z 120 120 "$SOURCE" --out "$SET_DIR/AppIcon-40@3x.png" >/dev/null
sips -z 120 120 "$SOURCE" --out "$SET_DIR/AppIcon-60@2x.png" >/dev/null
sips -z 180 180 "$SOURCE" --out "$SET_DIR/AppIcon-60@3x.png" >/dev/null
sips -z 1024 1024 "$SOURCE" --out "$SET_DIR/AppIcon-1024.png" >/dev/null

# Make sure Xcode's asset compiler sees PNGs rather than the temporary PDF/SVG artwork.
rm -f "$SET_DIR/AppIcon.pdf" "$SET_DIR/AppIcon.svg"

echo "Generated LAST CALL iOS app icon set from $SOURCE"
