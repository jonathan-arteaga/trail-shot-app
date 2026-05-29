#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TrailShot"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_TEMP_PATH="$DIST_DIR/$APP_NAME.tmp.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
CODE_SIGN_IDENTITY="${TRAILSHOT_CODE_SIGN_IDENTITY:--}"
VERIFY_LAUNCH="${TRAILSHOT_PACKAGE_VERIFY_LAUNCH:-0}"
export TRAILSHOT_RELEASE_CHANNEL="${TRAILSHOT_RELEASE_CHANNEL:-development}"

cleanup_dmg_mounts() {
  while IFS= read -r device; do
    [[ -n "$device" ]] || continue
    hdiutil detach "$device" -force >/dev/null 2>&1 || true
  done < <(hdiutil info | awk -v volume="/Volumes/$APP_NAME" '$0 ~ volume {print $1}')
}

create_dmg() {
  local attempt

  for attempt in 1 2 3; do
    rm -f "$DMG_TEMP_PATH" "$DMG_PATH"
    if hdiutil create \
      -volname "$APP_NAME" \
      -srcfolder "$STAGING_DIR" \
      -ov \
      -format UDZO \
      "$DMG_TEMP_PATH"; then
      mv "$DMG_TEMP_PATH" "$DMG_PATH"
      return 0
    fi

    cleanup_dmg_mounts
    sleep "$((attempt * 2))"
  done

  return 1
}

swift test

if [[ "$VERIFY_LAUNCH" == "1" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --verify
else
  "$ROOT_DIR/script/build_and_run.sh" --bundle-only
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
cleanup_dmg_mounts
rm -rf "$STAGING_DIR" "$DMG_PATH" "$DMG_TEMP_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

create_dmg

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODE_SIGN_IDENTITY" "$DMG_PATH"
fi

"$ROOT_DIR/script/validate_release_artifact.sh"

echo "$DMG_PATH"
