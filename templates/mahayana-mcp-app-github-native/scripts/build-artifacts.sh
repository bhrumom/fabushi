#!/usr/bin/env bash
set -euo pipefail
: "${VERSION:=0.1.0}"
VERSION="${VERSION#v}"
PLUGIN_ID="$(node -p "JSON.parse(require('fs').readFileSync('common/plugin.json', 'utf8')).pluginId")"
test -n "$PLUGIN_ID"
rm -rf dist .release-stage
mkdir -p dist .release-stage/common
cp -R common/. .release-stage/common/
cp tools.json permissions.json tool-contract.json LICENSE NOTICE .release-stage/common/
VERSION="$VERSION" PLUGIN_ID="$PLUGIN_ID" node - <<'NODE'
const fs = require('node:fs');
for (const path of ['.release-stage/common/plugin.json', '.release-stage/common/tool-contract.json']) {
  const value = JSON.parse(fs.readFileSync(path, 'utf8'));
  value.pluginId = process.env.PLUGIN_ID;
  value.version = process.env.VERSION;
  fs.writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}
NODE
tar -C .release-stage/common -czf dist/common.tar.gz .

build_native() {
  local goos="$1" goarch="$2" id="$3" binary="mahayana-app"
  local stage=".release-stage/$id"
  mkdir -p "$stage/bin"
  if [[ "$goos" == windows ]]; then binary="mahayana-app.exe"; fi
  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" go build -trimpath \
    -ldflags="-s -w -X github.com/example/mahayana-github-native-app/internal/contract.PluginID=$PLUGIN_ID -X github.com/example/mahayana-github-native-app/internal/contract.Version=$VERSION" \
    -o "$stage/bin/$binary" ./cmd/native
  cp LICENSE NOTICE tool-contract.json "$stage/"
  tar -C "$stage" -czf "dist/$id.tar.gz" .
}

build_native darwin arm64 native-macos-arm64
build_native darwin amd64 native-macos-x64
build_native windows amd64 native-windows-x64
build_native linux amd64 native-linux-x64
build_native linux arm64 native-linux-arm64

web_stage=.release-stage/web-wasm
mkdir -p "$web_stage"
GOOS=js GOARCH=wasm go build -trimpath \
  -ldflags="-s -w -X github.com/example/mahayana-github-native-app/internal/contract.PluginID=$PLUGIN_ID -X github.com/example/mahayana-github-native-app/internal/contract.Version=$VERSION" \
  -o "$web_stage/mahayana-app.wasm" ./cmd/webwasm
cp "$(go env GOROOT)/misc/wasm/wasm_exec.js" "$web_stage/wasm_exec.js"
cp runtime/web/worker.js tool-contract.json LICENSE NOTICE "$web_stage/"
tar -C "$web_stage" -czf dist/web-wasm.tar.gz .
sha256sum dist/*.tar.gz | sort > dist/SHA256SUMS
