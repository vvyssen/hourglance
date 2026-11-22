#!/bin/sh
# Builds CornerClock.app (universal) into ./build. Needs only the Command Line Tools.
set -e
cd "$(dirname "$0")"
APP=build/CornerClock.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 Sources/main.swift -o build/CornerClock-$arch
done
lipo -create build/CornerClock-arm64 build/CornerClock-x86_64 -output "$APP/Contents/MacOS/CornerClock"
rm build/CornerClock-arm64 build/CornerClock-x86_64
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
