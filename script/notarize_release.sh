#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TrailShot"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME.dmg"

if [[ -z "${TRAILSHOT_NOTARY_PROFILE:-}" ]]; then
  echo "Set TRAILSHOT_NOTARY_PROFILE to an xcrun notarytool keychain profile." >&2
  exit 2
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$TRAILSHOT_NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "$DMG_PATH"
