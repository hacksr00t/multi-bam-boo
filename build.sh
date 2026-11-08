#!/bin/bash
# Build Multi-Bam-Boo.app (menu bar app) and optionally install it + the `multibb` CLI.
#
#   ./build.sh               build into ./build, then install to /Applications and your bin dir
#   ./build.sh --no-install  just build
#
# Signing: by default the app is ad-hoc signed (fine for your own Mac).
# To sign with your Developer ID, set SIGN_ID, e.g.
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh
# For a notarized, shareable .zip use ./release.sh instead.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo 0.0.0)}"
APP_NAME="Multi-Bam-Boo"
EXEC="MultiBB"
BUNDLE_ID="${BUNDLE_ID:-io.github.hacksr00t.multibb}"
SIGN_ID="${SIGN_ID:--}"
INSTALL=1
[ "${1:-}" = "--no-install" ] && INSTALL=0

BUILD="build/$APP_NAME.app"
rm -rf build && mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"

# Universal binary (Apple Silicon + Intel), macOS 13+
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -o "build/$EXEC-$arch" app/MultiBB.swift
done
lipo -create -output "$BUILD/Contents/MacOS/$EXEC" "build/$EXEC-arm64" "build/$EXEC-x86_64"
rm -f build/$EXEC-*

cp multibb "$BUILD/Contents/Resources/multibb"
chmod +x "$BUILD/Contents/Resources/multibb"
cp HOW-TO-USE.md LICENSE "$BUILD/Contents/Resources/"

cat > "$BUILD/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXEC</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License. Based on bamboo-switch by c0ryd. Not affiliated with Bambu Lab.</string>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>$APP_NAME</string>
    <key>CFBundleURLSchemes</key><array><string>multibb</string></array>
  </dict></array>
</dict>
</plist>
PLIST

if [ "$SIGN_ID" = "-" ]; then
  codesign --force --sign - "$BUILD/Contents/Resources/multibb"
  codesign --force --sign - "$BUILD"
else
  # Hardened runtime + secure timestamp are required for notarization.
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$BUILD/Contents/Resources/multibb"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$BUILD"
fi
codesign --verify --strict "$BUILD"
echo "Built: $BUILD ($VERSION, signed with: $SIGN_ID)"

[ "$INSTALL" = 1 ] || exit 0

# Install the app (quit a running copy first)
pkill -x "$EXEC" 2>/dev/null && sleep 1 || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "$BUILD" "/Applications/$APP_NAME.app"
echo "Installed: /Applications/$APP_NAME.app"

# Install the CLI into the first writable bin dir on a sensible list
for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
  if [ -d "$dir" ] && [ -w "$dir" ]; then
    install -m 755 multibb "$dir/multibb"
    echo "Installed: $dir/multibb"
    case ":$PATH:" in *":$dir:"*) ;; *) echo "  (add $dir to your PATH to use 'multibb' in Terminal)";; esac
    exit 0
  fi
done
echo "Note: no writable bin dir found for the CLI. Copy ./multibb somewhere on your PATH (e.g. sudo cp multibb /usr/local/bin/)."
