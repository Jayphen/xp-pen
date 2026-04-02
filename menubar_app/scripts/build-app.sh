#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="XP-Pen Remote"
BUNDLE_ID="com.jayphen.xp-pen-remote"
VERSION="${1:-0.1.0}"

echo "Building release binary..."
swift build -c release

echo "Creating app bundle..."
APP_DIR="build/${APP_NAME}.app"
rm -rf build
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp .build/release/XPPenRemote "${APP_DIR}/Contents/MacOS/"

cat > "${APP_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>XPPenRemote</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>XP-Pen Remote needs Bluetooth to connect to your shortcut remote.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Signing..."
codesign --force --deep --sign - "${APP_DIR}"

echo "Creating zip..."
cd build
zip -r "XP-Pen-Remote-${VERSION}.zip" "${APP_NAME}.app"
cd ..

echo "Done: build/XP-Pen-Remote-${VERSION}.zip"
