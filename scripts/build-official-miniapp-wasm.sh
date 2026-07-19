#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/third_party/mahayana/mahayana-rs/Cargo.toml"
wasm="$repo_root/third_party/mahayana/mahayana-rs/target/wasm32-unknown-unknown/release/fabushi_official_miniapps.wasm"
out_dir="$repo_root/fabushi/web/mahayana-wasm/official-miniapps"

if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "wasm-bindgen CLI 0.2.126 is required." >&2
  exit 2
fi

rustup target add wasm32-unknown-unknown
cargo build \
  --release \
  --locked \
  --target wasm32-unknown-unknown \
  --manifest-path "$manifest" \
  --package fabushi-official-miniapps \
  --lib
wasm-bindgen \
  --target web \
  --out-dir "$out_dir" \
  --out-name fabushi_official_miniapps \
  "$wasm"
