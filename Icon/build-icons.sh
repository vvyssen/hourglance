#!/bin/sh
# Renders all four icon variants and the two .icns files the app ships with:
#   Hourglance.icns      = light (default, used in light mode)
#   HourglanceDark.icns  = notch (swapped in by the app in dark mode)
set -e
cd "$(dirname "$0")"
for s in notch light graphite sand; do swift make-icon.swift variants/$s.png $s; done
tmp=$(mktemp -d)
mkicns() {
  set=$tmp/$2.iconset; mkdir -p $set
  for s in 16 32 128 256 512; do
    sips -z $s $s $1 --out $set/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) $1 --out $set/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $set -o $2.icns
}
mkicns variants/light.png Hourglance
mkicns variants/notch.png HourglanceDark
rm -rf $tmp
echo "icons built"
