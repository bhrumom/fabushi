#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$PLUGIN_DIR/runtime/macos"

mkdir -p "$OUTPUT_DIR"
xcrun swiftc \
  -O \
  -framework ApplicationServices \
  -framework AppKit \
  "$PLUGIN_DIR/native/chatgpt_auto_confirm.swift" \
  -o "$OUTPUT_DIR/chatgpt-auto-confirm"
