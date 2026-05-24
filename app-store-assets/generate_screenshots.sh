#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

MAGICK="${MAGICK:-$(command -v magick || true)}"
IDENTIFY="${IDENTIFY:-$(command -v identify || true)}"

if [[ -z "$MAGICK" ]]; then
  echo "ImageMagick 'magick' is required to regenerate App Store screenshots." >&2
  exit 1
fi

if [[ -z "$IDENTIFY" ]]; then
  IDENTIFY="$MAGICK identify"
fi

BRAND_PRIMARY="#1F2747"
BRAND_DARK="#1F2937"
BRAND_BLUE="#36447C"
BRAND_MID="#8391C9"
BRAND_LIGHT="#CAD0E8"
BRAND_BG="#050608"
BRAND_SURFACE="#090a0e"
BRAND_CARD="#191d26"
BRAND_LINE="#36447C"

FONT="Helvetica"
BOLD="Helvetica-Bold"

make_text() {
  local width="$1"
  local height="$2"
  local size="$3"
  local weight="$4"
  local fill="$5"
  local text="$6"
  local outfile="$7"
  "$MAGICK" -size "${width}x${height}" -background none -fill "$fill" -font "$weight" \
    -gravity center -pointsize "$size" "caption:${text}" "$outfile"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if [[ -f "$ROOT/branding/source/Urbanist.zip" ]]; then
  unzip -q "$ROOT/branding/source/Urbanist.zip" static/Urbanist-Regular.ttf static/Urbanist-Bold.ttf -d "$tmpdir/font"
  FONT="$tmpdir/font/static/Urbanist-Regular.ttf"
  BOLD="$tmpdir/font/static/Urbanist-Bold.ttf"
fi

# iPhone 6.5-inch screenshot: 1242 x 2688
make_text 1040 270 104 "$BOLD" "#ffffff" $'One task,\nalways visible' "$tmpdir/iphone-title.png"
make_text 980 150 44 "$FONT" "$BRAND_LIGHT" "Keep the current objective on your desk in StandBy Mode." "$tmpdir/iphone-subtitle.png"
make_text 740 70 34 "$FONT" "$BRAND_MID" "Ship Hold" "$tmpdir/iphone-root.png"
make_text 780 95 48 "$FONT" "$BRAND_LIGHT" "Finalize App Store page" "$tmpdir/iphone-parent.png"
make_text 760 250 92 "$BOLD" "#ffffff" "Upload screenshots" "$tmpdir/iphone-current.png"
"$MAGICK" -size 1242x2688 gradient:"${BRAND_PRIMARY}-${BRAND_BG}" \
  "$tmpdir/iphone-title.png" -gravity north -geometry +0+140 -composite \
  "$tmpdir/iphone-subtitle.png" -gravity north -geometry +0+420 -composite \
  -fill "#000000" -stroke "$BRAND_BLUE" -strokewidth 3 -draw "roundrectangle 156,700 1086,2260 72,72" \
  -fill "$BRAND_SURFACE" -stroke "$BRAND_DARK" -strokewidth 2 -draw "roundrectangle 206,760 1036,2200 52,52" \
  "$tmpdir/iphone-root.png" -gravity north -geometry +0+980 -composite \
  -fill "$BRAND_MID" -font "$BOLD" -pointsize 48 -gravity center -annotate +0-178 "↓" \
  "$tmpdir/iphone-parent.png" -gravity center -geometry +0-82 -composite \
  "$tmpdir/iphone-current.png" -gravity center -geometry +0+130 -composite \
  -fill "#ffffff" -draw "circle 571,1902 577,1902" \
  -fill "#ffffff66" -draw "circle 621,1902 627,1902" \
  -fill "#ffffff66" -draw "circle 671,1902 677,1902" \
  -alpha remove -alpha off \
  -depth 8 -strip "$OUT/hold-iphone-65.png"

# iPad Pro 12.9-inch screenshot: 2048 x 2732
make_text 1660 260 112 "$BOLD" "#ffffff" "Your current objective, held" "$tmpdir/ipad-title.png"
make_text 1360 140 48 "$FONT" "$BRAND_LIGHT" "Hold shows one thing at a time, so you can return to work without scanning another list." "$tmpdir/ipad-subtitle.png"
make_text 1280 90 44 "$FONT" "$BRAND_MID" "Write launch notes" "$tmpdir/ipad-root.png"
make_text 1280 110 58 "$FONT" "$BRAND_LIGHT" "Prepare release checklist" "$tmpdir/ipad-parent.png"
make_text 1320 300 116 "$BOLD" "#ffffff" "Submit for review" "$tmpdir/ipad-current.png"
"$MAGICK" -size 2048x2732 gradient:"${BRAND_PRIMARY}-${BRAND_BG}" \
  "$tmpdir/ipad-title.png" -gravity north -geometry +0+180 -composite \
  "$tmpdir/ipad-subtitle.png" -gravity north -geometry +0+440 -composite \
  -fill "#000000" -stroke "$BRAND_BLUE" -strokewidth 4 -draw "roundrectangle 244,760 1804,2280 86,86" \
  -fill "$BRAND_SURFACE" -stroke "$BRAND_DARK" -strokewidth 2 -draw "roundrectangle 314,840 1734,2200 56,56" \
  "$tmpdir/ipad-root.png" -gravity north -geometry +0+1070 -composite \
  -fill "$BRAND_MID" -font "$BOLD" -pointsize 58 -gravity center -annotate +0-205 "↓" \
  "$tmpdir/ipad-parent.png" -gravity center -geometry +0-85 -composite \
  "$tmpdir/ipad-current.png" -gravity center -geometry +0+150 -composite \
  -fill "#ffffff" -draw "circle 974,1914 983,1914" \
  -fill "#ffffff66" -draw "circle 1024,1914 1033,1914" \
  -fill "#ffffff66" -draw "circle 1074,1914 1083,1914" \
  -alpha remove -alpha off \
  -depth 8 -strip "$OUT/hold-ipad-129.png"

# macOS desktop screenshot: 2880 x 1800
make_text 980 130 72 "$BOLD" "#ffffff" "Capture at speed of thought" "$tmpdir/mac-title.png"
make_text 880 110 36 "$FONT" "$BRAND_LIGHT" "Use the Mac hotkey to update the one task mirrored on your iPhone." "$tmpdir/mac-subtitle.png"
make_text 900 105 42 "$FONT" "#f7f8fb" "Update onboarding copy" "$tmpdir/mac-field.png"
make_text 720 76 34 "$FONT" "$BRAND_MID" "Ship Hold" "$tmpdir/mac-root.png"
make_text 760 92 46 "$FONT" "$BRAND_LIGHT" "Prepare launch" "$tmpdir/mac-parent.png"
make_text 760 190 74 "$BOLD" "#ffffff" "Update onboarding copy" "$tmpdir/mac-current.png"
"$MAGICK" -size 2880x1800 gradient:"${BRAND_PRIMARY}-${BRAND_BG}" \
  "$tmpdir/mac-title.png" -gravity northwest -geometry +180+170 -composite \
  "$tmpdir/mac-subtitle.png" -gravity northwest -geometry +184+305 -composite \
  -fill "$BRAND_CARD" -stroke "$BRAND_LINE" -strokewidth 2 -draw "roundrectangle 170,520 1320,760 28,28" \
  "$tmpdir/mac-field.png" -gravity northwest -geometry +250+588 -composite \
  -fill "$BRAND_BLUE" -draw "roundrectangle 1110,592 1246,688 24,24" \
  -fill "#ffffff" -font "$BOLD" -pointsize 31 -gravity northwest -annotate +1145+652 "↵" \
  -fill "#0c0d11" -stroke "$BRAND_BLUE" -strokewidth 3 -draw "roundrectangle 1570,150 2570,1640 74,74" \
  -fill "$BRAND_SURFACE" -stroke "$BRAND_DARK" -strokewidth 2 -draw "roundrectangle 1632,228 2508,1562 52,52" \
  "$tmpdir/mac-root.png" -gravity northeast -geometry +520+565 -composite \
  -fill "$BRAND_MID" -font "$BOLD" -pointsize 48 -gravity northeast -annotate +960+790 "↓" \
  "$tmpdir/mac-parent.png" -gravity northeast -geometry +492+800 -composite \
  "$tmpdir/mac-current.png" -gravity northeast -geometry +488+1010 -composite \
  -fill "#ffffff" -draw "circle 2018,1385 2026,1385" \
  -fill "#ffffff66" -draw "circle 2068,1385 2076,1385" \
  -fill "#ffffff66" -draw "circle 2118,1385 2126,1385" \
  -alpha remove -alpha off \
  -depth 8 -strip "$OUT/hold-mac-desktop.png"

$IDENTIFY "$OUT"/*.png
