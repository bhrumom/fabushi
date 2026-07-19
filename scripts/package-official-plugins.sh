#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
destination="${2:-}"
if [ -z "$target" ] || [ -z "$destination" ]; then
  echo "usage: $0 <macos|linux|windows> <destination>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/.agents/plugins"
release_root="$repo_root/third_party/mahayana/mahayana-rs/target/release"
wasm_root="$repo_root/fabushi/web/mahayana-wasm/official-miniapps"

case "$target" in
  windows) cli_source="$release_root/fabushi-plugin-cli.exe" ;;
  macos|linux) cli_source="$release_root/fabushi-plugin-cli" ;;
  *) echo "unsupported target: $target" >&2; exit 2 ;;
esac

if [ ! -f "$cli_source" ]; then
  echo "official Mini App CLI was not built: $cli_source" >&2
  exit 1
fi
if [ ! -f "$wasm_root/fabushi_official_miniapps_bg.wasm" ]; then
  echo "official Mini App WASM was not built: $wasm_root" >&2
  exit 1
fi

mkdir -p "$destination/plugins"
cp "$source_root/marketplace.json" "$destination/marketplace.json"
for plugin_source in "$source_root"/plugins/*; do
  [ -d "$plugin_source" ] || continue
  plugin_id="$(basename "$plugin_source")"
  plugin_destination="$destination/plugins/$plugin_id"
  mkdir -p "$plugin_destination"
  cp -R "$plugin_source"/. "$plugin_destination"/
  mkdir -p "$plugin_destination/runtime/cli" "$plugin_destination/runtime/wasm"
  if [ "$target" = "windows" ]; then
    cp "$cli_source" "$plugin_destination/runtime/cli/fabushi-plugin-cli.exe"
  else
    cp "$cli_source" "$plugin_destination/runtime/cli/fabushi-plugin-cli"
    chmod 0755 "$plugin_destination/runtime/cli/fabushi-plugin-cli"
  fi
  cp -R "$wasm_root"/. "$plugin_destination/runtime/wasm"/
done

echo "Packaged official plugins and their CLI/WASM runtimes into $destination"
