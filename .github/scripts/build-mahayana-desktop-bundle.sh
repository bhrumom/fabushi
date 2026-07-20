#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: $0 <macos|linux|windows> [bundle-dir] [full|cli-only]" >&2
  exit 2
fi
bundle_override="${2:-}"
bundle_mode="${3:-full}"
if [ "$bundle_mode" != "full" ] && [ "$bundle_mode" != "cli-only" ]; then
  echo "unsupported Mahayana bundle mode: $bundle_mode" >&2
  exit 2
fi
if [ ! -f "pubspec.yaml" ]; then
  echo "Run this script from the fabushi Flutter project directory." >&2
  exit 2
fi

repo_root="$(cd .. && pwd)"
runtime_root="$repo_root/third_party/mahayana"
manifest="$runtime_root/mahayana-rs/Cargo.toml"
if [ ! -f "$manifest" ]; then
  echo "Submodule manifest not found at $manifest. Initializing submodules..." >&2
  git -C "$repo_root" submodule update --init --recursive
fi
target_dir="$runtime_root/mahayana-rs/target/release"

cargo build --release --locked --manifest-path "$manifest" \
  --package mahayana-cli
cargo build --release --locked --manifest-path "$manifest" \
  --package fabushi-official-miniapps --bin fabushi-plugin-cli

if [ "$bundle_mode" = "full" ]; then
  if [ "$target" = "linux" ]; then
    cargo rustc --release --locked --manifest-path "$manifest" \
      --package mahayana-ffi --no-default-features --features linux-shared,local-only \
      --crate-type cdylib
  else
    cargo rustc --release --locked --manifest-path "$manifest" \
      --package mahayana-ffi \
      --crate-type cdylib
  fi
fi

case "$target" in
  macos)
    bundle="${bundle_override:-build/macos/Build/Products/Release/global_dharma_sharing.app/Contents}"
    cli_source="$target_dir/mahayana"
    runtime_source="$target_dir/libmahayana_runtime.dylib"
    cli_destination="$bundle/MacOS/mahayana"
    runtime_destination="$bundle/Frameworks/libmahayana_runtime.dylib"
    share_destination="$bundle/Resources/mahayana/share"
    plugin_cli_name="fabushi-plugin-cli"
    ;;
  linux)
    bundle="${bundle_override:-build/linux/x64/release/bundle}"
    cli_source="$target_dir/mahayana"
    runtime_source="$target_dir/libmahayana_runtime.so"
    cli_destination="$bundle/mahayana"
    runtime_destination="$bundle/lib/libmahayana_runtime.so"
    share_destination="$bundle/share"
    plugin_cli_name="fabushi-plugin-cli"
    ;;
  windows)
    bundle="${bundle_override:-build/windows/x64/runner/Release}"
    cli_source="$target_dir/mahayana.exe"
    runtime_source="$target_dir/mahayana_runtime.dll"
    cli_destination="$bundle/mahayana.exe"
    runtime_destination="$bundle/mahayana_runtime.dll"
    share_destination="$bundle/share"
    plugin_cli_name="fabushi-plugin-cli.exe"
    ;;
  *)
    echo "unsupported Mahayana desktop target: $target" >&2
    exit 2
    ;;
esac

sources=("$cli_source")
if [ "$bundle_mode" = "full" ]; then
  sources+=("$runtime_source")
fi
for source in "${sources[@]}"; do
  if [ ! -f "$source" ]; then
    echo "Mahayana desktop asset was not built: $source" >&2
    exit 1
  fi
done

mkdir -p \
  "$(dirname "$cli_destination")" \
  "$(dirname "$runtime_destination")" \
  "$share_destination/licenses/codex" \
  "$share_destination/mahayana"
cp "$cli_source" "$cli_destination"
if [ "$bundle_mode" = "full" ]; then
  cp "$runtime_source" "$runtime_destination"
fi
cp "$runtime_root/LICENSE" "$share_destination/licenses/codex/LICENSE"
cp "$runtime_root/mahayana-rs/UPSTREAM.md" \
  "$share_destination/mahayana/UPSTREAM.md"
cp "$runtime_root/mahayana-rs/UPSTREAM.lock" \
  "$share_destination/mahayana/UPSTREAM.lock"
plugins_destination="$share_destination/mahayana/plugins"
"$repo_root/scripts/package-official-plugins.sh" \
  "$target" "$plugins_destination"

if [ "$target" != "windows" ]; then
  chmod 0755 "$cli_destination"
  if [ "$bundle_mode" = "full" ]; then
    chmod 0644 "$runtime_destination"
  fi
fi

"$cli_destination" help >/dev/null
smoke_home="$(mktemp -d)"
trap 'rm -rf "$smoke_home"' EXIT
status_json="$(MAHAYANA_HOME="$smoke_home" "$cli_destination" status)"
grep -Eq '"model"[[:space:]]*:[[:space:]]*"deepseek-chat"' <<<"$status_json"
grep -Eq '"modelProvider"[[:space:]]*:[[:space:]]*"first-party-dacheng"' <<<"$status_json"
grep -Eq '"remoteAgentEnabled"[[:space:]]*:[[:space:]]*false' <<<"$status_json"

if [ ! -f "$plugins_destination/marketplace.json" ]; then
  echo "Bundled official plugin marketplace is missing." >&2
  exit 1
fi
plugin_cli="$(find "$plugins_destination/plugins" -path "*/runtime/cli/$plugin_cli_name" -type f -print -quit)"
if [ -z "$plugin_cli" ]; then
  echo "Bundled official plugin CLI is missing for $target." >&2
  exit 1
fi
plugin_wasm="$(find "$plugins_destination/plugins" -path '*/runtime/wasm/*.wasm' -type f -print -quit)"
if [ -z "$plugin_wasm" ]; then
  echo "Bundled official plugin WASM runtime is missing." >&2
  exit 1
fi

echo "Bundled the in-process Mahayana CLI ($bundle_mode) into $bundle"
