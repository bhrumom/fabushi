#!/usr/bin/env bash
set -euo pipefail

APP_NAME="global_dharma_sharing"
DISPLAY_NAME="全球法布施"
APP_VERSION="${APP_VERSION:-1.0.0}"
VERSION_SLUG="${APP_VERSION//+/-}"
ARCH="${DESKTOP_ARCH:-$(uname -m)}"
OUT_DIR="${OUT_DIR:-desktop-artifacts}"
APP_PATH="build/macos/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "macOS app bundle not found: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

DMG_PATH="$OUT_DIR/$APP_NAME-$VERSION_SLUG-macos-$ARCH.dmg"
ZIP_PATH="$OUT_DIR/$APP_NAME-$VERSION_SLUG-macos-$ARCH.zip"

rm -f "$DMG_PATH" "$ZIP_PATH"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created $DMG_PATH"
echo "Created $ZIP_PATH"
