#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRAND_DIR="$ROOT/app-store-assets/branding"
SOURCE_ZIP="$BRAND_DIR/source/hold_logo_package.zip"
MAGICK="${MAGICK:-$(command -v magick || true)}"

if [[ -z "$MAGICK" ]]; then
  echo "ImageMagick 'magick' is required to regenerate Hold app icons." >&2
  exit 1
fi

if [[ ! -f "$SOURCE_ZIP" ]]; then
  echo "Missing source package: $SOURCE_ZIP" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
unzip -q "$SOURCE_ZIP" -d "$TMP_DIR"

APP_ICON_SOURCE="$TMP_DIR/hold_inverse_avatar.png"
MENU_ICON_SOURCE="$TMP_DIR/hold_icon_white.png"

make_app_icon() {
  local size="$1"
  local output="$2"
  "$MAGICK" "$APP_ICON_SOURCE" \
    -background '#1F2747' \
    -alpha remove \
    -alpha off \
    -resize "${size}x${size}!" \
    -depth 8 \
    -strip \
    "$output"
}

make_template_icon() {
  local size="$1"
  local output="$2"
  "$MAGICK" "$MENU_ICON_SOURCE" \
    -resize "${size}x${size}!" \
    -depth 8 \
    -strip \
    "$output"
}

make_app_icon 16 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"
make_app_icon 32 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png"
make_app_icon 32 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_32x32.png"
make_app_icon 64 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png"
make_app_icon 128 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_128x128.png"
make_app_icon 256 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png"
make_app_icon 256 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png"
make_app_icon 512 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png"
make_app_icon 512 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
make_app_icon 1024 "$ROOT/HoldApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"

make_app_icon 120 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon@2x.png"
make_app_icon 180 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon@3x.png"
make_app_icon 76 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon~ipad.png"
make_app_icon 152 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon@2x~ipad.png"
make_app_icon 167 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-83.5@2x~ipad.png"
make_app_icon 80 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-40@2x.png"
make_app_icon 120 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-40@3x.png"
make_app_icon 40 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-40~ipad.png"
make_app_icon 80 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-40@2x~ipad.png"
make_app_icon 40 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-20@2x.png"
make_app_icon 60 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-20@3x.png"
make_app_icon 20 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-20~ipad.png"
make_app_icon 40 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-20@2x~ipad.png"
make_app_icon 29 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-29.png"
make_app_icon 58 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-29@2x.png"
make_app_icon 87 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-29@3x.png"
make_app_icon 29 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-29~ipad.png"
make_app_icon 58 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-29@2x~ipad.png"
make_app_icon 120 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-60@2x~car.png"
make_app_icon 180 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-60@3x~car.png"
make_app_icon 1024 "$ROOT/HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png"

make_template_icon 176 "$ROOT/HoldApp/Assets.xcassets/hold_icon.imageset/hold_icon.png"

echo "Regenerated Hold app icons from $SOURCE_ZIP"
