#!/bin/bash
# Checks a packaged Stint disk image the way a user installs it: mounts it, checks what's
# inside, copies the app out, and verifies its signature, version, architecture and bundled
# files. Also checks the matching .zip and SHA256SUMS.txt when they sit next to it.
#
#   Scripts/verify-package.sh dist/Stint-2.1.0.dmg
#
# With LAUNCH=1 (the default on CI) it also opens the installed copy and checks that it starts
# and keeps running. Locally that's off, so it doesn't start a second Stint beside yours.
set -euo pipefail

DMG="${1:?usage: Scripts/verify-package.sh dist/Stint-<version>.dmg}"
LAUNCH="${LAUNCH:-${CI:+1}}"
DIST="$(cd "$(dirname "$DMG")" && pwd)"
NAME="$(basename "$DMG" .dmg)"         # Stint-2.1.0
VERSION="${NAME#Stint-}"

WORK="$(mktemp -d)"
MOUNT="$WORK/mount"
mkdir -p "$MOUNT"
cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

passed() { echo "✓ $*"; }
failed() { echo "✗ $*" >&2; exit 1; }

# The disk image: the app plus a shortcut to Applications for drag-to-install.
attach() {
    if diskutil image attach -h >/dev/null 2>&1; then # macOS 26+
        diskutil image attach --readOnly --mountOptions nobrowse --mountPoint "$MOUNT" "$DMG" >/dev/null
    else
        hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG" >/dev/null
    fi
}
attach || failed "the disk image doesn't mount"
[[ -d "$MOUNT/Stint.app" ]] || failed "the disk image has no Stint.app"
[[ "$(readlink "$MOUNT/Applications")" == "/Applications" ]] || failed "the Applications shortcut is missing"
passed "disk image mounts with Stint.app and an Applications shortcut"

# Install a copy, as dragging it to Applications would.
APP="$WORK/Applications/Stint.app"
mkdir -p "$WORK/Applications"
ditto "$MOUNT/Stint.app" "$APP"
hdiutil detach "$MOUNT" -quiet

codesign --verify --deep --strict "$APP" || failed "the code signature doesn't verify"
passed "code signature is valid"

plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist"; }
[[ "$(plist CFBundleIdentifier)" == "app.stint.Stint" ]] || failed "unexpected bundle identifier $(plist CFBundleIdentifier)"
[[ "$(plist CFBundleShortVersionString)" == "$VERSION" ]] || failed "the app says version $(plist CFBundleShortVersionString), the file says $VERSION"
passed "app.stint.Stint version $VERSION (build $(plist CFBundleVersion)), macOS $(plist LSMinimumSystemVersion)+"

lipo -archs "$APP/Contents/MacOS/Stint" | grep -qw arm64 || failed "the app isn't built for Apple silicon"
passed "built for $(lipo -archs "$APP/Contents/MacOS/Stint")"

for resource in AppIcon.icns Blocked.html Stint.sdef; do
    [[ -s "$APP/Contents/Resources/$resource" ]] || failed "Resources/$resource is missing"
done
passed "icon, blocked page and AppleScript dictionary are bundled"

if xcrun stapler validate "$APP" >/dev/null 2>&1; then
    spctl --assess --type execute "$APP" || failed "Gatekeeper rejects the notarized app"
    passed "notarized, and Gatekeeper accepts it"
else
    echo "· not notarized (ad-hoc signed): users approve it once in Privacy & Security"
fi

# The zip and checksums published beside it.
if [[ -f "$DIST/$NAME.zip" ]]; then
    listing="$(unzip -l "$DIST/$NAME.zip")" # read it whole: grep -q in a pipe would cut unzip off
    grep -q "Stint.app/Contents/MacOS/Stint" <<<"$listing" || failed "$NAME.zip doesn't contain the app"
    passed "$NAME.zip contains the app"
fi
if [[ -f "$DIST/SHA256SUMS.txt" ]]; then
    (cd "$DIST" && shasum -a 256 -c SHA256SUMS.txt >/dev/null) || failed "SHA256SUMS.txt doesn't match the files"
    passed "checksums match"
fi

# Open the installed copy and make sure it starts and stays up.
if [[ "$LAUNCH" == "1" ]]; then
    "$APP/Contents/MacOS/Stint" >/dev/null 2>&1 &
    PID=$!
    sleep 8
    kill -0 "$PID" 2>/dev/null || failed "the app quit right after launching"
    kill "$PID"
    wait "$PID" 2>/dev/null || true
    passed "the installed app launches and keeps running"
fi

echo "$NAME.dmg looks good."
