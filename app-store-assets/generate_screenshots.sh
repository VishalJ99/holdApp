#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

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
  magick -size "${width}x${height}" -background none -fill "$fill" -font "$weight" \
    -gravity center -pointsize "$size" "caption:${text}" "$outfile"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# iPhone 6.5-inch screenshot: 1242 x 2688
make_text 1040 270 104 "$BOLD" "#ffffff" $'One task,\nalways visible' "$tmpdir/iphone-title.png"
make_text 980 150 44 "$FONT" "#b9c0ca" "Keep the current objective on your desk in StandBy Mode." "$tmpdir/iphone-subtitle.png"
make_text 740 70 34 "$FONT" "#9aa0aa" "Ship Hold" "$tmpdir/iphone-root.png"
make_text 780 95 48 "$FONT" "#c2c7d1" "Finalize App Store page" "$tmpdir/iphone-parent.png"
make_text 760 250 92 "$BOLD" "#ffffff" "Upload screenshots" "$tmpdir/iphone-current.png"
magick -size 1242x2688 gradient:"#11131a-#050608" \
  "$tmpdir/iphone-title.png" -gravity north -geometry +0+140 -composite \
  "$tmpdir/iphone-subtitle.png" -gravity north -geometry +0+420 -composite \
  -fill "#000000" -stroke "#2a2f39" -strokewidth 3 -draw "roundrectangle 156,700 1086,2260 72,72" \
  -fill "#0a0b0f" -stroke "#1f2430" -strokewidth 2 -draw "roundrectangle 206,760 1036,2200 52,52" \
  "$tmpdir/iphone-root.png" -gravity north -geometry +0+980 -composite \
  -fill "#687080" -font "$BOLD" -pointsize 48 -gravity center -annotate +0-178 "↓" \
  "$tmpdir/iphone-parent.png" -gravity center -geometry +0-82 -composite \
  "$tmpdir/iphone-current.png" -gravity center -geometry +0+130 -composite \
  -fill "#ffffff" -draw "circle 571,1902 577,1902" \
  -fill "#ffffff66" -draw "circle 621,1902 627,1902" \
  -fill "#ffffff66" -draw "circle 671,1902 677,1902" \
  -depth 8 -strip "$OUT/hold-iphone-65.png"

# iPad Pro 12.9-inch screenshot: 2048 x 2732
make_text 1660 260 112 "$BOLD" "#ffffff" "Your current objective, held" "$tmpdir/ipad-title.png"
make_text 1360 140 48 "$FONT" "#b9c0ca" "Hold shows one thing at a time, so you can return to work without scanning another list." "$tmpdir/ipad-subtitle.png"
make_text 1280 90 44 "$FONT" "#9aa0aa" "Write launch notes" "$tmpdir/ipad-root.png"
make_text 1280 110 58 "$FONT" "#c2c7d1" "Prepare release checklist" "$tmpdir/ipad-parent.png"
make_text 1320 300 116 "$BOLD" "#ffffff" "Submit for review" "$tmpdir/ipad-current.png"
magick -size 2048x2732 gradient:"#10131a-#050608" \
  "$tmpdir/ipad-title.png" -gravity north -geometry +0+180 -composite \
  "$tmpdir/ipad-subtitle.png" -gravity north -geometry +0+440 -composite \
  -fill "#000000" -stroke "#2a2f39" -strokewidth 4 -draw "roundrectangle 244,760 1804,2280 86,86" \
  -fill "#090a0e" -stroke "#1f2430" -strokewidth 2 -draw "roundrectangle 314,840 1734,2200 56,56" \
  "$tmpdir/ipad-root.png" -gravity north -geometry +0+1070 -composite \
  -fill "#687080" -font "$BOLD" -pointsize 58 -gravity center -annotate +0-205 "↓" \
  "$tmpdir/ipad-parent.png" -gravity center -geometry +0-85 -composite \
  "$tmpdir/ipad-current.png" -gravity center -geometry +0+150 -composite \
  -fill "#ffffff" -draw "circle 974,1914 983,1914" \
  -fill "#ffffff66" -draw "circle 1024,1914 1033,1914" \
  -fill "#ffffff66" -draw "circle 1074,1914 1083,1914" \
  -depth 8 -strip "$OUT/hold-ipad-129.png"

# macOS desktop screenshot: 2880 x 1800
make_text 980 130 72 "$BOLD" "#ffffff" "Capture at speed of thought" "$tmpdir/mac-title.png"
make_text 880 110 36 "$FONT" "#b9c0ca" "Use the Mac hotkey to update the one task mirrored on your iPhone." "$tmpdir/mac-subtitle.png"
make_text 900 105 42 "$FONT" "#f7f8fb" "Update onboarding copy" "$tmpdir/mac-field.png"
make_text 720 76 34 "$FONT" "#9aa0aa" "Ship Hold" "$tmpdir/mac-root.png"
make_text 760 92 46 "$FONT" "#c2c7d1" "Prepare launch" "$tmpdir/mac-parent.png"
make_text 760 190 74 "$BOLD" "#ffffff" "Update onboarding copy" "$tmpdir/mac-current.png"
magick -size 2880x1800 gradient:"#10131a-#050608" \
  "$tmpdir/mac-title.png" -gravity northwest -geometry +180+170 -composite \
  "$tmpdir/mac-subtitle.png" -gravity northwest -geometry +184+305 -composite \
  -fill "#191d26" -stroke "#343b49" -strokewidth 2 -draw "roundrectangle 170,520 1320,760 28,28" \
  "$tmpdir/mac-field.png" -gravity northwest -geometry +250+588 -composite \
  -fill "#2b3240" -draw "roundrectangle 1110,592 1246,688 24,24" \
  -fill "#ffffff" -font "$BOLD" -pointsize 31 -gravity northwest -annotate +1145+652 "↵" \
  -fill "#0c0d11" -stroke "#2a2f39" -strokewidth 3 -draw "roundrectangle 1570,150 2570,1640 74,74" \
  -fill "#090a0e" -stroke "#1f2430" -strokewidth 2 -draw "roundrectangle 1632,228 2508,1562 52,52" \
  "$tmpdir/mac-root.png" -gravity northeast -geometry +520+565 -composite \
  -fill "#687080" -font "$BOLD" -pointsize 48 -gravity northeast -annotate +960+790 "↓" \
  "$tmpdir/mac-parent.png" -gravity northeast -geometry +492+800 -composite \
  "$tmpdir/mac-current.png" -gravity northeast -geometry +488+1010 -composite \
  -fill "#ffffff" -draw "circle 2018,1385 2026,1385" \
  -fill "#ffffff66" -draw "circle 2068,1385 2076,1385" \
  -fill "#ffffff66" -draw "circle 2118,1385 2126,1385" \
  -depth 8 -strip "$OUT/hold-mac-desktop.png"

identify "$OUT"/*.png
