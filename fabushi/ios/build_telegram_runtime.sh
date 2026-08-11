#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
if [[ ! -f "$manifest" ]]; then
  echo "Submodule manifest not found at $manifest. Initializing submodules..." >&2
  git -C "$project_root" submodule update --init --recursive
fi
output="$project_root/fabushi/ios/Runner/Libs/libmahayana_runtime.a"
fingerprint_file="${output}.fingerprint"
configuration="${CONFIGURATION:-Debug}"
profile="debug"
release_build=0
if [[ "$configuration" != "Debug" ]]; then
  profile="release"
  release_build=1
fi

compute_fingerprint() {
  local archs="${ARCHS:-arm64}"
  local platform="${PLATFORM_NAME:-iphoneos}"
  {
    printf 'fabushi.mahayana.ios-runtime-fingerprint.v1\n'
    printf 'configuration=%s\n' "$configuration"
    printf 'profile=%s\n' "$profile"
    printf 'platform=%s\n' "$platform"
    printf 'archs=%s\n' "$archs"
    printf 'cargo_profile_dev_debug=%s\n' "${CARGO_PROFILE_DEV_DEBUG:-default}"
    printf '%s\n' '--- rustc ---'
    rustc -vV
    printf '%s\n' '--- cargo ---'
    cargo -V
    printf '%s\n' '--- tracked build inputs ---'
    (
      cd "$project_root"
      find \
        third_party/mahayana/mahayana-rs \
        third_party/mahayana/codex-rs \
        -type f \
        ! -path '*/target/*' \
        ! -path '*/.git/*' \
        -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 shasum -a 256
      shasum -a 256 fabushi/ios/build_telegram_runtime.sh
    )
  } | shasum -a 256 | awk '{print $1}'
}

fingerprint="$(compute_fingerprint)"
if [[ "${1:-}" == "--fingerprint" ]]; then
  printf '%s\n' "$fingerprint"
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Unsupported argument: $1" >&2
  exit 2
fi

if [[ -s "$output" && -f "$fingerprint_file" ]]; then
  cached_fingerprint="$(tr -d '\r\n' < "$fingerprint_file")"
  if [[ "$cached_fingerprint" == "$fingerprint" ]]; then
    echo "Reusing fingerprinted Mahayana Rust runtime: $output"
    exit 0
  fi
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
fingerprint_tmp="${fingerprint_file}.tmp.$$"
printf '%s\n' "$fingerprint" > "$fingerprint_tmp"
mv -f "$fingerprint_tmp" "$fingerprint_file"
