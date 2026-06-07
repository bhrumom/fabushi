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
RW_DMG_PATH="$OUT_DIR/$APP_NAME-$VERSION_SLUG-macos-$ARCH-rw.dmg"
TEMP_ROOT="${RUNNER_TEMP:-/tmp}"
DMG_MOUNT_POINT="$TEMP_ROOT/${APP_NAME}-dmg-mount"

rm -f "$DMG_PATH" "$ZIP_PATH" "$RW_DMG_PATH"
rm -rf "$DMG_MOUNT_POINT"
mkdir -p "$DMG_MOUNT_POINT"

app_size_kb="$(du -sk "$APP_PATH" | awk '{ print $1 }')"
dmg_size_mb=$((app_size_kb / 1024 + 256))
if [ "$dmg_size_mb" -lt 512 ]; then
  dmg_size_mb=512
fi

hdiutil create \
  -volname "$DISPLAY_NAME" \
  -fs HFS+ \
  -size "${dmg_size_mb}m" \
  -ov \
  "$RW_DMG_PATH"

hdiutil attach "$RW_DMG_PATH" -nobrowse -mountpoint "$DMG_MOUNT_POINT"
cleanup_mount() {
  hdiutil detach "$DMG_MOUNT_POINT" -quiet >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT

ditto "$APP_PATH" "$DMG_MOUNT_POINT/$APP_NAME.app"
ln -s /Applications "$DMG_MOUNT_POINT/Applications"

# Give Finder enough metadata to show the expected drag-to-Applications install view.
osascript <<APPLESCRIPT || true
tell application "Finder"
  tell disk "$DISPLAY_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 640, 420}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set position of item "$APP_NAME.app" of container window to {160, 150}
    set position of item "Applications" of container window to {420, 150}
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DMG_MOUNT_POINT"
trap - EXIT
rm -rf "$DMG_MOUNT_POINT"

hdiutil convert "$RW_DMG_PATH" -format UDZO -o "$DMG_PATH"
rm -f "$RW_DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created $DMG_PATH"
echo "Created $ZIP_PATH"
