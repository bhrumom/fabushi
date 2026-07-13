#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
crate_dir="$(dirname "$manifest")"
output="$project_root/fabushi/android/app/src/main/jniLibs"

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "cargo-ndk is required to build the Telegram Rust runtime." >&2
  echo "Install it with: cargo install cargo-ndk --locked" >&2
  exit 2
fi

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  ndk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/ndk"
  if [[ ! -d "$ndk_root" ]]; then
    echo "Android NDK directory not found: $ndk_root" >&2
    exit 2
  fi
  ANDROID_NDK_HOME="$(find "$ndk_root" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
  export ANDROID_NDK_HOME
fi

for target in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android; do
  rustup target add "$target"
done

cd "$crate_dir"
cargo ndk \
  --platform 24 \
  --target arm64-v8a \
  --target armeabi-v7a \
  --target x86_64 \
  --output-dir "$output" \
  build \
  --manifest-path "$manifest" \
  --package mahayana-ffi \
  --no-default-features \
  --features mobile-embedded,local-only \
  --release

# cargo-ndk also stages cdylib artifacts exposed by path dependencies. The
# unified wrapper exports both the new Mahayana ABI and the legacy Telegram ABI.
for abi in arm64-v8a armeabi-v7a x86_64; do
  rm -f \
    "$output/$abi/libfabushi_telegram_core.so" \
    "$output/$abi/libfabushi_telegram_protocol.so" \
    "$output/$abi/libfabushi_telegram_storage.so" \
    "$output/$abi/libfabushi_telegram_runtime.so" \
    "$output/$abi/libfabushi_miniapp_runtime.so"
done
