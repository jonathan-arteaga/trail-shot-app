#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TrailShot"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle: $APP_BUNDLE" >&2
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  exit 1
fi

plutil -lint "$INFO_PLIST" >/dev/null

required_bundle_id="com.salesforce.trailshot"
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
if [[ "$actual_bundle_id" != "$required_bundle_id" ]]; then
  echo "Unexpected bundle id: $actual_bundle_id" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
hdiutil verify "$DMG_PATH" >/dev/null

signature_details="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1)"
echo "$signature_details" | grep -q "Runtime Version" || {
  echo "Missing hardened runtime signature option" >&2
  exit 1
}

if echo "$signature_details" | grep -q "Signature=adhoc"; then
  echo "Validated ad-hoc signed development artifact."
  echo "Set TRAILSHOT_CODE_SIGN_IDENTITY='Developer ID Application: ...' for distributable signing."
else
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  echo "Validated Developer ID signed app artifact."
fi
