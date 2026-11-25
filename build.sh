#!/bin/zsh
# Builds ScreenSide.app (and ScreenSide.zip for releases) into ./build. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=1.0.0

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ScreenSide"

APP=build/ScreenSide.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ScreenSide"
cp Design/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.ajb93.screenside</string>
  <key>CFBundleName</key><string>ScreenSide</string>
  <key>CFBundleDisplayName</key><string>ScreenSide</string>
  <key>CFBundleExecutable</key><string>ScreenSide</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>ScreenSide uses your location to apply display arrangements you saved for a specific place (e.g. home vs office).</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>ScreenSide uses your location to apply display arrangements you saved for a specific place (e.g. home vs office).</string>
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>ScreenSide uses your location to apply display arrangements you saved for a specific place (e.g. home vs office).</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
(cd build && rm -f ScreenSide.zip && ditto -c -k --keepParent ScreenSide.app ScreenSide.zip)
echo "Zipped build/ScreenSide.zip"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x ScreenSide || true
  rm -rf /Applications/ScreenSide.app
  cp -R "$APP" /Applications/
  open /Applications/ScreenSide.app
  echo "Installed and launched /Applications/ScreenSide.app"
fi
