#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Network6.app/Contents"
DMG_DIR="$DIST_DIR/dmg"
DMG_NAME="Network6-${VERSION}"

echo "🔨 Building Network6 v${VERSION} (release)..."
cd "$PROJECT_DIR"
swift build -c release --product Network6App

BIN_PATH="$(swift build -c release --product Network6App --show-bin-path)/Network6App"

echo "📦 Creating .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

cp "$BIN_PATH" "$APP_DIR/MacOS/Network6"
chmod +x "$APP_DIR/MacOS/Network6"

cat > "$APP_DIR/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Network6</string>
    <key>CFBundleIdentifier</key>
    <string>com.network6.app</string>
    <key>CFBundleName</key>
    <string>Network6</string>
    <key>CFBundleDisplayName</key>
    <string>Network6</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Network6. MIT License.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

echo "💿 Creating DMG..."
mkdir -p "$DMG_DIR"
cp -R "$DIST_DIR/Network6.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

rm -f "$DIST_DIR/${DMG_NAME}.dmg"
hdiutil create \
    -volname "Network6" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/${DMG_NAME}.dmg"

rm -rf "$DMG_DIR"

echo ""
echo "✅ Done!"
echo "   App:  $DIST_DIR/Network6.app"
echo "   DMG:  $DIST_DIR/${DMG_NAME}.dmg"
echo "   Size: $(du -h "$DIST_DIR/${DMG_NAME}.dmg" | cut -f1)"
