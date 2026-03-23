#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PrinterLauncher"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist/$APP_NAME.app"
MACOS_DIR="$DIST_DIR/Contents/MacOS"
RESOURCES_DIR="$DIST_DIR/Contents/Resources"
INFO_PLIST="$DIST_DIR/Contents/Info.plist"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# SPM 번들 리소스 복사 (printer_harness.py 등)
BUNDLE_DIR="$BUILD_DIR/PrinterLauncher_PrinterLauncher.bundle"
if [ -d "$BUNDLE_DIR" ]; then
  cp -r "$BUNDLE_DIR/." "$RESOURCES_DIR/"
fi

cat > "$INFO_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PrinterLauncher</string>
    <key>CFBundleIdentifier</key>
    <string>com.boram.PrinterLauncher</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PrinterLauncher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Packaged app: $DIST_DIR"
