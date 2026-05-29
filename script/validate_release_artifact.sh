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

required_min_system_version="14.0"
actual_min_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
if [[ "$actual_min_system_version" != "$required_min_system_version" ]]; then
  echo "Unexpected minimum system version: $actual_min_system_version" >&2
  exit 1
fi

required_category="public.app-category.productivity"
actual_category="$(/usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$INFO_PLIST")"
if [[ "$actual_category" != "$required_category" ]]; then
  echo "Unexpected app category: $actual_category" >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
build_commit="$(/usr/libexec/PlistBuddy -c 'Print :TrailShotBuildCommit' "$INFO_PLIST")"
release_channel="$(/usr/libexec/PlistBuddy -c 'Print :TrailShotReleaseChannel' "$INFO_PLIST")"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Unexpected app version: $version" >&2
  exit 1
fi
if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  echo "Unexpected build number: $build_number" >&2
  exit 1
fi
if [[ -z "$build_commit" ]]; then
  echo "Missing TrailShotBuildCommit" >&2
  exit 1
fi
if [[ -z "$release_channel" ]]; then
  echo "Missing TrailShotReleaseChannel" >&2
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
