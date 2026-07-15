#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$project_root/third_party/mahayana/mahayana-rs/Cargo.toml"
if [[ ! -f "$manifest" ]]; then
  echo "Submodule manifest not found at $manifest. Initializing submodules..." >&2
  git -C "$project_root" submodule update --init --recursive
fi

configuration="${1:-Debug}"
output_dir="${2:-$project_root/fabushi/build/linux/telegram_runtime}"
profile="debug"
release_build=0

if [[ "$configuration" != "Debug" ]]; then
  profile="release"
  release_build=1
fi

cargo_args=(
  rustc
  --manifest-path "$manifest"
  --package mahayana-ffi
  --no-default-features
  --features linux-shared,local-only
)
if [[ "$release_build" -eq 1 ]]; then
  cargo_args+=(--release)
fi
cargo_args+=(--crate-type cdylib)
cargo "${cargo_args[@]}"

mkdir -p "$output_dir"
cp -f \
  "$project_root/third_party/mahayana/mahayana-rs/target/$profile/libmahayana_runtime.so" \
  "$output_dir/libmahayana_runtime.so"
