#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
commit="a17f87c4cff7b90b278d12b91ba0614383aaee82"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for schema in td_api.tl telegram_api.tl mtproto_api.tl; do
  curl -fsSL \
    "https://raw.githubusercontent.com/tdlib/td/$commit/td/generate/scheme/$schema" \
    -o "$tmp/$schema"
done

cd "$repo_root"
cargo run --quiet --manifest-path native/telegram-protocol/Cargo.toml \
  --bin td-schema-audit -- td "$tmp/td_api.tl"
cargo run --quiet --manifest-path native/telegram-protocol/Cargo.toml \
  --bin td-schema-audit -- telegram "$tmp/telegram_api.tl"
cargo run --quiet --manifest-path native/telegram-protocol/Cargo.toml \
  --bin td-schema-audit -- mtproto "$tmp/mtproto_api.tl"
cargo run --quiet --manifest-path native/telegram-protocol/Cargo.toml \
  --bin tl-schema-codegen -- \
  "$tmp/telegram_api.tl" \
  "$tmp/mtproto_api.tl" \
  native/telegram-protocol/src/generated/schema_ids.rs
