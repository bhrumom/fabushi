#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: $0 <macos|linux|windows>" >&2
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

if [ "$target" = "linux" ]; then
  cargo rustc --release --locked --manifest-path "$manifest" \
    --package mahayana-ffi --no-default-features --features linux-shared,local-only \
    --crate-type cdylib
else
  cargo rustc --release --locked --manifest-path "$manifest" \
    --package mahayana-ffi \
    --crate-type cdylib
fi

case "$target" in
  macos)
    bundle="build/macos/Build/Products/Release/global_dharma_sharing.app/Contents"
    cli_source="$target_dir/mahayana"
    runtime_source="$target_dir/libmahayana_runtime.dylib"
    cli_destination="$bundle/MacOS/mahayana"
    runtime_destination="$bundle/Frameworks/libmahayana_runtime.dylib"
    share_destination="$bundle/Resources/mahayana/share"
    ;;
  linux)
    bundle="build/linux/x64/release/bundle"
    cli_source="$target_dir/mahayana"
    runtime_source="$target_dir/libmahayana_runtime.so"
    cli_destination="$bundle/mahayana"
    runtime_destination="$bundle/lib/libmahayana_runtime.so"
    share_destination="$bundle/share"
    ;;
  windows)
    bundle="build/windows/x64/runner/Release"
    cli_source="$target_dir/mahayana.exe"
    runtime_source="$target_dir/mahayana_runtime.dll"
    cli_destination="$bundle/mahayana.exe"
    runtime_destination="$bundle/mahayana_runtime.dll"
    share_destination="$bundle/share"
    ;;
  *)
    echo "unsupported Mahayana desktop target: $target" >&2
    exit 2
    ;;
esac

for source in "$cli_source" "$runtime_source"; do
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
cp "$runtime_source" "$runtime_destination"
cp "$runtime_root/LICENSE" "$share_destination/licenses/codex/LICENSE"
cp "$runtime_root/mahayana-rs/UPSTREAM.md" \
  "$share_destination/mahayana/UPSTREAM.md"
cp "$runtime_root/mahayana-rs/UPSTREAM.lock" \
  "$share_destination/mahayana/UPSTREAM.lock"

if [ "$target" != "windows" ]; then
  chmod 0755 "$cli_destination"
  chmod 0644 "$runtime_destination"
fi

"$cli_destination" help >/dev/null
smoke_home="$(mktemp -d)"
trap 'rm -rf "$smoke_home"' EXIT
MAHAYANA_HOME="$smoke_home" "$cli_destination" status >/dev/null
MAHAYANA_HOME="$smoke_home" "$cli_destination" miniapp execute \
  '{"@type":"runtime.getStatus"}' >/dev/null
echo "Bundled the in-process Mahayana CLI and Runtime into $bundle"
