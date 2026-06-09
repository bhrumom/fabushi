#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
APP_NAME="global_dharma_sharing"
CLI_NAME="global_dharma_sharing_cli"

if [ -z "$TARGET" ]; then
  echo "usage: $0 <macos|linux|windows>" >&2
  exit 2
fi

if [ ! -f "tool/desktop_package_cli.dart" ]; then
  echo "Run this script from the fabushi Flutter project directory." >&2
  exit 2
fi

case "$TARGET" in
  macos)
    OUT="build/macos/Build/Products/Release/$APP_NAME.app/Contents/MacOS/$CLI_NAME"
    ;;
  linux)
    OUT="build/linux/x64/release/bundle/$CLI_NAME"
    ;;
  windows)
    OUT="build/windows/x64/runner/Release/$CLI_NAME.exe"
    ;;
  *)
    echo "unsupported desktop CLI target: $TARGET" >&2
    exit 2
    ;;
esac

mkdir -p "$(dirname "$OUT")"
dart compile exe tool/desktop_package_cli.dart -o "$OUT"
if [ "$TARGET" != "windows" ]; then
  chmod +x "$OUT"
fi
"$OUT" version
