#!/bin/bash
# Builds Stint and packages it for distribution into dist/:
#   Stint-<version>.zip   the app, zipped with ditto (keeps signatures and metadata)
#   Stint-<version>.dmg   a disk image with an Applications shortcut for drag-to-install
#
# Notarization (optional, needs a Developer ID build; see build-app.sh):
#   NOTARY_PROFILE=<keychain profile created with `xcrun notarytool store-credentials`>
#   NOTARY_KEYCHAIN=<keychain holding that profile, if not the login keychain>
set -euo pipefail
cd "$(dirname "$0")/.."

Scripts/build-app.sh

APP="build/Stint.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DIST="dist"
ZIP="$DIST/Stint-$VERSION.zip"
DMG="$DIST/Stint-$VERSION.dmg"
mkdir -p "$DIST"
rm -f "$ZIP" "$DMG"

notarize() {
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" \
        ${NOTARY_KEYCHAIN:+--keychain "$NOTARY_KEYCHAIN"} --wait
}

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    # Notarize the app itself, then staple the ticket so it verifies offline.
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    notarize "$DIST/notarize.zip"
    rm "$DIST/notarize.zip"
    xcrun stapler staple "$APP"
fi

ditto -c -k --keepParent "$APP" "$ZIP"

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
if diskutil image create from -h >/dev/null 2>&1; then
    # macOS 26+ replacement for `hdiutil create`.
    diskutil image create from --format UDZO --volumeName "Stint $VERSION" "$STAGING" "$DMG" >/dev/null
else
    hdiutil create -volname "Stint $VERSION" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
fi
rm -rf "$STAGING"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    notarize "$DMG"
    xcrun stapler staple "$DMG"
fi

# Bare file names, so `shasum -c SHA256SUMS.txt` works next to the downloads.
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")") | tee "$DIST/SHA256SUMS.txt"
echo "Packaged Stint $VERSION into $DIST/"
