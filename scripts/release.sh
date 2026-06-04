#!/usr/bin/env bash
#
# Build a signed + notarized DiskSpace.dmg for free public distribution.
#
# Prerequisites (one-time, see docs/DISTRIBUTION.md):
#   - Apple Developer Program membership
#   - A "Developer ID Application" certificate in your login keychain
#   - A notarytool keychain profile (xcrun notarytool store-credentials)
#
# Required environment variables:
#   DEVELOPER_ID_APP   e.g. "Developer ID Application: Jane Dev (AB12CD34EF)"
#   NOTARY_PROFILE     the notarytool keychain profile name you created
#
# Usage:
#   DEVELOPER_ID_APP="Developer ID Application: …" NOTARY_PROFILE="diskspace" \
#       scripts/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="DiskSpace"
BUNDLE_ID="com.diskspace.app"
VERSION="1.1"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
APP="$STAGE/$APP_NAME.app"
ICNS="$ROOT/.build/AppIcon.icns"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

if [ -z "${DEVELOPER_ID_APP:-}" ] || [ -z "${NOTARY_PROFILE:-}" ]; then
    cat <<'MSG'
error: signing/notarization credentials are not set.

This script needs a paid Apple Developer account. Set:
  DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
  NOTARY_PROFILE="<your notarytool keychain profile>"

See docs/DISTRIBUTION.md for the full one-time setup. For a local, personal
install instead, use scripts/package.sh (ad-hoc signed, no notarization).
MSG
    exit 1
fi

# A universal binary is built as two single-arch builds + lipo, rather than
# `swift build --arch …` (which requires full Xcode's xcbuild). arm64 builds
# natively; x86_64 cross-compiles via an explicit target triple.
echo "==> Building arm64 slice (native)"
swift build -c release
ARM_BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> Building x86_64 slice (cross-compile)"
swift build -c release --scratch-path "$ROOT/.build-x86" \
    -Xswiftc -target -Xswiftc x86_64-apple-macosx14.0 \
    -Xcc -target -Xcc x86_64-apple-macosx14.0
X86_BIN="$ROOT/.build-x86/release/$APP_NAME"

echo "==> Merging into a universal binary (lipo)"
UNIVERSAL_BIN="$ROOT/.build/$APP_NAME-universal"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$UNIVERSAL_BIN"
echo "    architectures: $(lipo -archs "$UNIVERSAL_BIN")"

echo "==> Preparing icon"
if [ ! -f "$ICNS" ]; then
    ICONSET="$ROOT/.build/AppIcon.iconset"
    rm -rf "$ICONSET"
    swift "$ROOT/scripts/make-icon.swift" "$ICONSET"
    iconutil -c icns "$ICONSET" -o "$ICNS"
fi

echo "==> Assembling $APP_NAME.app"
rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$UNIVERSAL_BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing with Developer ID (hardened runtime + timestamp)"
codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APP" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Building DMG"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"

echo "==> Notarizing (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper acceptance (assess the app inside the DMG)"
MOUNT="$(mktemp -d)"
hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MOUNT"
spctl -a -t exec -vv "$MOUNT/$APP_NAME.app" || true
hdiutil detach "$MOUNT" -quiet || true

echo "==> Done. Distributable: $DMG"
