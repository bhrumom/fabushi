#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/native/telegram-runtime/Cargo.toml"
frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
output="$frameworks_dir/libfabushi_telegram_runtime.dylib"
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
  rustup target add "$target"
  cargo_args=(
    build
    --manifest-path "$manifest"
    --target "$target"
  )
  if [[ "$release_build" -eq 1 ]]; then
    cargo_args+=(--release)
  fi
  cargo "${cargo_args[@]}"
  artifacts+=(
    "$project_root/native/telegram-runtime/target/$target/$profile/libfabushi_telegram_runtime.dylib"
  )
done

if [[ ${#artifacts[@]} -eq 1 ]]; then
  cp -f "${artifacts[0]}" "$output"
else
  lipo -create "${artifacts[@]}" -output "$output"
fi

install_name_tool -id "@rpath/libfabushi_telegram_runtime.dylib" "$output"
if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    --preserve-metadata=identifier,entitlements,flags "$output"
fi
