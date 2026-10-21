#!/bin/bash
# Assembles build/Stint.app from the Swift package.
#
# Signing:
#   default                   ad-hoc signature (runs on this Mac; others must approve it in Gatekeeper)
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
#                             Developer ID signature with the hardened runtime, ready for notarization
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Stint.app"
BUILD_FLAGS=(-c release --arch arm64)

swift build "${BUILD_FLAGS[@]}"
BIN="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Stint" "$APP/Contents/MacOS/Stint"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Stint.sdef Resources/Blocked.html "$APP/Contents/Resources/"

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift Scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp \
        --entitlements Resources/Stint.entitlements \
        --sign "$CODESIGN_IDENTITY" "$APP"
    echo "Signed with: $CODESIGN_IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "Signed ad-hoc (set CODESIGN_IDENTITY for a Developer ID build)"
fi
codesign --verify --strict "$APP"
echo "Built $APP ($(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist"))"
