#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TrailShot"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
CODE_SIGN_IDENTITY="${TRAILSHOT_CODE_SIGN_IDENTITY:--}"

"$ROOT_DIR/script/build_and_run.sh" --verify

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODE_SIGN_IDENTITY" "$DMG_PATH"
fi

"$ROOT_DIR/script/validate_release_artifact.sh"

echo "$DMG_PATH"
