#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-ClashBar}"
APP_VERSION="${APP_VERSION:-3.6.1}"
DMG_SUFFIX="${DMG_SUFFIX:-}"
VOLUME_NAME="${DMG_VOLUME_NAME:-${APP_NAME}}"

APP_PATH="$ROOT/dist/${APP_NAME}.app"
if [ -n "$DMG_SUFFIX" ]; then
  DMG_NAME="${APP_NAME}-${APP_VERSION}-${DMG_SUFFIX}.dmg"
else
  DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
fi
DMG_PATH="$ROOT/dist/${DMG_NAME}"
DMG_SHA_PATH="${DMG_PATH}.sha256"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found at $APP_PATH. Run ./Scripts/package_app.sh first." >&2
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -f "$DMG_PATH" "$DMG_SHA_PATH"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

( cd "$ROOT/dist" && shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256" )

echo "Created dmg: $DMG_PATH"
echo "Checksum: $DMG_SHA_PATH"
