#!/usr/bin/env bash
set -euo pipefail

APP_NAME="global_dharma_sharing"
CLI_NAME="global_dharma_sharing_cli"
PACKAGE_NAME="global-dharma-sharing"
DISPLAY_NAME="全球法布施"
APP_VERSION="${APP_VERSION:-1.0.0}"
VERSION_SLUG="${APP_VERSION//+/-}"
ARCH="${DEB_ARCH:-amd64}"
OUT_DIR="${OUT_DIR:-desktop-artifacts}"
BUNDLE_DIR="build/linux/x64/release/bundle"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "Linux release bundle not found: $BUNDLE_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TAR_PATH="$OUT_DIR/$APP_NAME-$VERSION_SLUG-linux-x64.tar.gz"
DEB_PATH="$OUT_DIR/${PACKAGE_NAME}_${VERSION_SLUG}_${ARCH}.deb"
DEB_ROOT="${RUNNER_TEMP:-/tmp}/${PACKAGE_NAME}-deb"

rm -rf "$DEB_ROOT" "$TAR_PATH" "$DEB_PATH"
mkdir -p \
  "$DEB_ROOT/DEBIAN" \
  "$DEB_ROOT/opt/$PACKAGE_NAME" \
  "$DEB_ROOT/usr/bin" \
  "$DEB_ROOT/usr/share/applications"

cp -a "$BUNDLE_DIR/." "$DEB_ROOT/opt/$PACKAGE_NAME/"
ln -s "/opt/$PACKAGE_NAME/$APP_NAME" "$DEB_ROOT/usr/bin/$PACKAGE_NAME"
ln -s "/opt/$PACKAGE_NAME/$CLI_NAME" "$DEB_ROOT/usr/bin/global-dharma-sharing-cli"
ln -s "/opt/$PACKAGE_NAME/mahayana" "$DEB_ROOT/usr/bin/mahayana"

installed_size="$(du -sk "$DEB_ROOT/opt/$PACKAGE_NAME" | awk '{print $1}')"
cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION_SLUG
Section: utils
Priority: optional
Architecture: $ARCH
Installed-Size: $installed_size
Maintainer: bhrumom <support@fabushi.com>
Depends: libgtk-3-0, liblzma5, libstdc++6, libgcc-s1, libasound2 | libasound2t64
Description: Global Dharma Sharing desktop application
 A Flutter desktop application for Buddhist scripture and dharma sharing.
EOF

cat > "$DEB_ROOT/usr/share/applications/$PACKAGE_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$DISPLAY_NAME
Comment=Global Dharma Sharing
Exec=/opt/$PACKAGE_NAME/$APP_NAME
Terminal=false
Categories=Utility;Education;
StartupWMClass=com.ombhrum.fabushi
EOF

chmod 0755 "$DEB_ROOT/DEBIAN"
fakeroot dpkg-deb --build --root-owner-group "$DEB_ROOT" "$DEB_PATH"

tar -C "$BUNDLE_DIR" -czf "$TAR_PATH" .

echo "Created $DEB_PATH"
echo "Created $TAR_PATH"
