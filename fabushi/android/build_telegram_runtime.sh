#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
crate_dir="$(dirname "$manifest")"
output="$project_root/fabushi/android/app/src/main/jniLibs"

if [[ ! -f "$manifest" ]]; then
  echo "Submodule manifest not found at $manifest. Initializing submodules..." >&2
  git -C "$project_root" submodule update --init --recursive
fi

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "cargo-ndk is required to build the embedded Mahayana Runtime." >&2
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
  rustc \
  --manifest-path "$manifest" \
  --package mahayana-ffi \
  --no-default-features \
  --features mobile-embedded,local-only \
  --release \
  -- \
  --crate-type cdylib

# Provider crates are Rust-only libraries. The unified wrapper is the sole
# staged native artifact and exports both the Mahayana ABI and legacy bridges.
