#!/usr/bin/env bash
#
# Build DiskSpace, wrap it in a proper .app bundle (icon + Info.plist),
# ad-hoc code-sign it, and install to /Applications so it shows up in
# Finder, Launchpad, and Spotlight.
#
# Usage: scripts/package.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="DiskSpace"
BUNDLE_ID="com.diskspace.app"
RELEASE_DIR="$ROOT/.build/release"
STAGE="$ROOT/.build/app"
APP="$STAGE/$APP_NAME.app"
ICONSET="$ROOT/.build/AppIcon.iconset"
ICNS="$ROOT/.build/AppIcon.icns"
INSTALL_DIR="/Applications"
DEST="$INSTALL_DIR/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release

echo "==> Preparing icon"
if [ ! -f "$ICNS" ]; then
    rm -rf "$ICONSET"
    swift "$ROOT/scripts/make-icon.swift" "$ICONSET"
    iconutil -c icns "$ICONSET" -o "$ICNS"
    echo "    created $ICNS"
else
    echo "    using cached $ICNS"
fi

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$RELEASE_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

echo "==> Stopping any running instance"
pkill -x "$APP_NAME" 2>/dev/null || true

echo "==> Installing to $DEST"
if [ -w "$INSTALL_DIR" ] || { [ -e "$DEST" ] && [ -w "$DEST" ]; }; then
    rm -rf "$DEST"
    cp -R "$APP" "$INSTALL_DIR/"
    echo "    installed."
else
    echo "    $INSTALL_DIR is not writable without admin rights."
    echo "    Run this yourself to finish the install:"
    echo "      sudo rm -rf '$DEST' && sudo cp -R '$APP' '$INSTALL_DIR/'"
    exit 0
fi

echo "==> Done. Launch with:  open -a $APP_NAME"
