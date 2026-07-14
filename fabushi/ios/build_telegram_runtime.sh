#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
output="$project_root/fabushi/ios/Runner/Libs/libmahayana_runtime.a"
configuration="${CONFIGURATION:-Debug}"
profile="debug"
release_build=0
if [[ "$configuration" != "Debug" ]]; then
  profile="release"
  release_build=1
fi

artifacts=()
for arch in ${ARCHS:-arm64}; do
  if [[ "${PLATFORM_NAME:-iphoneos}" == "iphonesimulator" ]]; then
    case "$arch" in
      arm64) target="aarch64-apple-ios-sim" ;;
      x86_64) target="x86_64-apple-ios" ;;
      *)
        echo "Unsupported iOS Simulator architecture: $arch" >&2
        exit 2
        ;;
    esac
  else
    case "$arch" in
      arm64) target="aarch64-apple-ios" ;;
      *)
        echo "Unsupported iOS device architecture: $arch" >&2
        exit 2
        ;;
    esac
  fi
  rustup target add "$target"
  cargo_args=(
    rustc
    --manifest-path "$manifest"
    --package mahayana-ffi
    --no-default-features
    --features mobile-embedded,local-only
    --target "$target"
    --crate-type staticlib
  )
  if [[ "$release_build" -eq 1 ]]; then
    cargo_args+=(--release)
  fi
  cargo "${cargo_args[@]}"
  artifacts+=(
    "$project_root/third_party/mahayana/mahayana-rs/target/$target/$profile/libmahayana_runtime.a"
  )
done

mkdir -p "$(dirname "$output")"
if [[ ${#artifacts[@]} -eq 1 ]]; then
  cp -f "${artifacts[0]}" "$output"
else
  lipo -create "${artifacts[@]}" -output "$output"
fi
