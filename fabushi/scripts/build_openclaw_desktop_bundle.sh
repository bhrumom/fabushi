#!/usr/bin/env bash
set -euo pipefail

# Build/release-time vendor script for the embedded OpenClaw runtime.
# It is intended for CI or the developer machine that creates the desktop app
# package. End users never run this script and never install Node/npm/OpenClaw.
#
# Usage:
#   scripts/build_openclaw_desktop_bundle.sh macos-arm64
#   OPENCLAW_VERSION=2026.6.1 scripts/build_openclaw_desktop_bundle.sh linux-x64
#
# Output:
#   assets/openclaw/<platform>/node/...
#   assets/openclaw/<platform>/openclaw/...

PLATFORM="${1:-}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-2026.6.1}"
OPENCLAW_WEIXIN_VERSION="${OPENCLAW_WEIXIN_VERSION:-2.4.3}"
OPENCLAW_WEIXIN_PACKAGE="${OPENCLAW_WEIXIN_PACKAGE:-@tencent-weixin/openclaw-weixin@$OPENCLAW_WEIXIN_VERSION}"
OPENCLAW_BUNDLE_WEIXIN="${OPENCLAW_BUNDLE_WEIXIN:-1}"
NODE_VERSION="${NODE_VERSION:-24.18.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/assets/openclaw/$PLATFORM"
WORK_DIR="$ROOT_DIR/.dart_tool/openclaw_bundle/$PLATFORM"

if [[ -z "$PLATFORM" ]]; then
  echo "usage: $0 <macos-arm64|macos-x64|linux-x64|linux-arm64|windows-x64|windows-arm64>" >&2
  exit 2
fi

case "$PLATFORM" in
  macos-arm64) NODE_DIST="node-v$NODE_VERSION-darwin-arm64" ;;
  macos-x64) NODE_DIST="node-v$NODE_VERSION-darwin-x64" ;;
  linux-x64) NODE_DIST="node-v$NODE_VERSION-linux-x64" ;;
  linux-arm64) NODE_DIST="node-v$NODE_VERSION-linux-arm64" ;;
  windows-x64) NODE_DIST="node-v$NODE_VERSION-win-x64" ;;
  windows-arm64) NODE_DIST="node-v$NODE_VERSION-win-arm64" ;;
  *) echo "unsupported platform: $PLATFORM" >&2; exit 2 ;;
esac

rm -rf "$WORK_DIR" "$OUT_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

pushd "$WORK_DIR" >/dev/null

echo "==> Downloading Node $NODE_VERSION for $PLATFORM"
if [[ "$PLATFORM" == windows-* ]]; then
  curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/$NODE_DIST.zip"
  unzip -q "$NODE_DIST.zip"
else
  curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/$NODE_DIST.tar.xz"
  tar -xf "$NODE_DIST.tar.xz"
fi
mv "$NODE_DIST" "$OUT_DIR/node"

if [[ "$PLATFORM" == windows-* ]]; then
  NODE_BIN="$OUT_DIR/node/node.exe"
  NPM_CMD=("$NODE_BIN" "$OUT_DIR/node/node_modules/npm/bin/npm-cli.js")
else
  NODE_BIN="$OUT_DIR/node/bin/node"
  NPM_CMD=("$OUT_DIR/node/bin/npm")
fi

install_published_package_dependencies() {
  # Registry tarballs can contain lock files generated from a different
  # package.json than the published manifest. Resolve from that manifest rather
  # than letting a stale bundled lock make npm ci fail during release vendoring.
  rm -f package-lock.json npm-shrinkwrap.json
  "${NPM_CMD[@]}" install \
    --omit=dev \
    --ignore-scripts=false \
    --package-lock=false
}

echo "==> Packing openclaw@$OPENCLAW_VERSION"
npm pack "openclaw@$OPENCLAW_VERSION" --pack-destination "$WORK_DIR" >/dev/null
OPENCLAW_TGZ="$(ls "$WORK_DIR"/openclaw-*.tgz | head -n 1)"
mkdir -p "$OUT_DIR/openclaw"
tar -xzf "$OPENCLAW_TGZ" -C "$OUT_DIR/openclaw" --strip-components=1

echo "==> Installing production dependencies into bundled OpenClaw package"
pushd "$OUT_DIR/openclaw" >/dev/null
install_published_package_dependencies
popd >/dev/null

if [[ "$OPENCLAW_BUNDLE_WEIXIN" != "0" ]]; then
  echo "==> Packing OpenClaw WeChat plugin: $OPENCLAW_WEIXIN_PACKAGE"
  npm pack "$OPENCLAW_WEIXIN_PACKAGE" --pack-destination "$WORK_DIR" >/dev/null
  WEIXIN_TGZ="$(find "$WORK_DIR" -maxdepth 1 -name '*openclaw-weixin*.tgz' | sort | tail -n 1)"
  if [[ -z "$WEIXIN_TGZ" ]]; then
    echo "failed to locate packed openclaw-weixin tarball" >&2
    exit 1
  fi
  mkdir -p "$OUT_DIR/plugins/openclaw-weixin"
  tar -xzf "$WEIXIN_TGZ" -C "$OUT_DIR/plugins/openclaw-weixin" --strip-components=1

  echo "==> Installing production dependencies into bundled WeChat plugin"
  pushd "$OUT_DIR/plugins/openclaw-weixin" >/dev/null
  install_published_package_dependencies
  popd >/dev/null
fi

if [[ "$PLATFORM" != windows-* ]]; then
  chmod +x "$NODE_BIN"
fi

python3 "$ROOT_DIR/scripts/update_openclaw_bundle_manifest.py" "$PLATFORM"

popd >/dev/null

echo "==> Embedded OpenClaw bundle ready: $OUT_DIR"
