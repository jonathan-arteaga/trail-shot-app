#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TrailShot"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME.dmg"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  exit 1
fi

if [[ -n "${TRAILSHOT_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$TRAILSHOT_NOTARY_PROFILE" \
    --wait
else
  if [[ -z "${TRAILSHOT_NOTARY_APPLE_ID:-}" || -z "${TRAILSHOT_NOTARY_PASSWORD:-}" || -z "${TRAILSHOT_NOTARY_TEAM_ID:-}" ]]; then
    echo "Set TRAILSHOT_NOTARY_PROFILE, or set TRAILSHOT_NOTARY_APPLE_ID, TRAILSHOT_NOTARY_PASSWORD, and TRAILSHOT_NOTARY_TEAM_ID." >&2
    exit 2
  fi

  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$TRAILSHOT_NOTARY_APPLE_ID" \
    --password "$TRAILSHOT_NOTARY_PASSWORD" \
    --team-id "$TRAILSHOT_NOTARY_TEAM_ID" \
    --wait
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "$DMG_PATH"
