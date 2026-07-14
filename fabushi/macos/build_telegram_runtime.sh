#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
output="$frameworks_dir/libmahayana_runtime.dylib"

# Xcode run-script phases do not inherit the user's interactive shell PATH.
# rustup installs its proxies here by default, so make them available when the
# app is built from Flutter/Xcode as well as from a terminal.
rust_bin_dir="${CARGO_HOME:-${HOME:-}/.cargo}/bin"
if [[ -d "$rust_bin_dir" ]]; then
  export PATH="$rust_bin_dir:$PATH"
fi

rustup_bin="$(command -v rustup || true)"
cargo_bin="$(command -v cargo || true)"
if [[ -z "$rustup_bin" || -z "$cargo_bin" ]]; then
  echo "Rust toolchain not found. Install rustup before building the macOS app." >&2
  exit 127
fi

configuration="${CONFIGURATION:-Debug}"
profile="debug"
release_build=0
if [[ "$configuration" != "Debug" ]]; then
  profile="release"
  release_build=1
fi

mkdir -p "$frameworks_dir"
artifacts=()
for arch in ${ARCHS:-$(uname -m)}; do
  case "$arch" in
    arm64) target="aarch64-apple-darwin" ;;
    x86_64) target="x86_64-apple-darwin" ;;
    *)
      echo "Unsupported macOS architecture: $arch" >&2
      exit 2
      ;;
  esac
  "$rustup_bin" target add "$target"
  cargo_args=(
    rustc
    --manifest-path "$manifest"
    --package mahayana-ffi
    --target "$target"
    --crate-type cdylib
  )
  if [[ "$release_build" -eq 1 ]]; then
    cargo_args+=(--release)
  fi
  "$cargo_bin" "${cargo_args[@]}"
  artifacts+=(
    "$project_root/third_party/mahayana/mahayana-rs/target/$target/$profile/libmahayana_runtime.dylib"
  )
done

if [[ ${#artifacts[@]} -eq 1 ]]; then
  cp -f "${artifacts[0]}" "$output"
else
  lipo -create "${artifacts[@]}" -output "$output"
fi

install_name_tool -id "@rpath/libmahayana_runtime.dylib" "$output"
if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    --preserve-metadata=identifier,entitlements,flags "$output"
fi
