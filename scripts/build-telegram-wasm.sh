#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/native/telegram-wasm/Cargo.toml"
wasm="$repo_root/native/telegram-wasm/target/wasm32-unknown-unknown/release/fabushi_telegram_wasm.wasm"
out_dir="$repo_root/fabushi/web/telegram-wasm"

if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "wasm-bindgen CLI 0.2.126 is required." >&2
  echo "Install it with: cargo install wasm-bindgen-cli --version 0.2.126 --locked" >&2
  exit 2
fi

rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown --manifest-path "$manifest"
wasm-bindgen \
  --target web \
  --out-dir "$out_dir" \
  --out-name fabushi_telegram \
  "$wasm"
