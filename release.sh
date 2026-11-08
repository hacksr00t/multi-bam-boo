#!/bin/bash
# Build a signed + notarized Multi-Bam-Boo.zip that opens cleanly on any Mac.
#
# One-time setup (needs a paid Apple Developer account):
#   1. Create a "Developer ID Application" certificate:
#        Xcode → Settings → Accounts → (your Apple ID) → Manage Certificates → + → Developer ID Application
#   2. Save notarization credentials in your keychain (use an app-specific password
#      from appleid.apple.com → Sign-In and Security → App-Specific Passwords):
#        xcrun notarytool store-credentials multibb-notary \
#          --apple-id you@example.com --team-id YOURTEAMID
#
# Then:  ./release.sh            (uses VERSION file)
#        VERSION=1.1.0 ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

NOTARY_PROFILE="${NOTARY_PROFILE:-multibb-notary}"
VERSION="${VERSION:-$(cat VERSION)}"

if [ -z "${SIGN_ID:-}" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
fi
if [ -z "$SIGN_ID" ]; then
  echo "No 'Developer ID Application' certificate found in your keychain." >&2
  echo "Create one in Xcode → Settings → Accounts → Manage Certificates (see top of this script)." >&2
  exit 1
fi
echo "Signing with: $SIGN_ID"

SIGN_ID="$SIGN_ID" VERSION="$VERSION" ./build.sh --no-install

mkdir -p dist
ZIP="dist/Multi-Bam-Boo-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Multi-Bam-Boo.app" "$ZIP"

echo "Submitting to Apple for notarization (usually 1-5 minutes)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

xcrun stapler staple "build/Multi-Bam-Boo.app"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Multi-Bam-Boo.app" "$ZIP"
spctl --assess --type execute -v "build/Multi-Bam-Boo.app"

cp multibb "dist/multibb"
( cd dist && shasum -a 256 "Multi-Bam-Boo-$VERSION.zip" multibb > SHA256SUMS.txt )

echo ""
echo "Release files in ./dist:"
ls -1 dist
echo ""
echo "Publish with:  gh release create v$VERSION dist/* --title \"Multi-Bam-Boo $VERSION\" --generate-notes"
