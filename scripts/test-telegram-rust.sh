#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifests=(
  "native/telegram-core/Cargo.toml"
  "native/telegram-protocol/Cargo.toml"
  "native/telegram-network/Cargo.toml"
  "native/telegram-storage/Cargo.toml"
  "native/telegram-runtime/Cargo.toml"
  "native/telegram-media/Cargo.toml"
  "native/telegram-wasm/Cargo.toml"
)

cd "$repo_root"
for manifest in "${manifests[@]}"; do
  cargo fmt --manifest-path "$manifest" -- --check
  cargo test --manifest-path "$manifest"
  cargo clippy --manifest-path "$manifest" --all-targets -- -D warnings
done
