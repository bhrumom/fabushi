#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
configuration="${1:-Debug}"
output_dir="${2:-$project_root/fabushi/build/linux/telegram_runtime}"
profile="debug"
release_build=0

if [[ "$configuration" != "Debug" ]]; then
  profile="release"
  release_build=1
fi

cargo_args=(
  build
  --manifest-path "$manifest"
  --package mahayana-ffi
)
if [[ "$release_build" -eq 1 ]]; then
  cargo_args+=(--release)
fi
cargo "${cargo_args[@]}"

mkdir -p "$output_dir"
cp -f \
  "$project_root/third_party/mahayana/mahayana-rs/target/$profile/libmahayana_runtime.so" \
  "$output_dir/libmahayana_runtime.so"
