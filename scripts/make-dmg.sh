#!/bin/sh
# Packages build/Hourglance.app into dist/Hourglance-<version>.dmg: the app next to an Applications
# shortcut, on a background with an arrow and a hint. Needs dmgbuild (pip install dmgbuild).
#   scripts/make-dmg.sh            # version from Info.plist
set -e
cd "$(dirname "$0")/.."
V=${1:-$(plutil -extract CFBundleShortVersionString raw Info.plist)}
[ -d build/Hourglance.app ] || { echo "build/Hourglance.app missing; run ./build.sh first" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
swift dmg/make-background.swift "$tmp/bg.png" 1
swift dmg/make-background.swift "$tmp/bg@2x.png" 2
tiffutil -cathidpicheck "$tmp/bg.png" "$tmp/bg@2x.png" -out "$tmp/bg.tiff" 2>/dev/null
mkdir -p dist
rm -f "dist/Hourglance-$V.dmg"
${DMGBUILD:-dmgbuild} -s dmg/settings.py -D app=build/Hourglance.app -D background="$tmp/bg.tiff" \
  -D volume_icon=Icon/Hourglance.icns "Hourglance" "dist/Hourglance-$V.dmg"
echo "Built dist/Hourglance-$V.dmg"
