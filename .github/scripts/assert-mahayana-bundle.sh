#!/usr/bin/env bash
set -euo pipefail

bundle_root="${1:-}"
target="${2:-}"
if [ -z "$bundle_root" ] || [ -z "$target" ]; then
  echo "usage: $0 <bundle-root> <macos|linux>" >&2
  exit 2
fi

case "$target" in
  macos)
    cli="$bundle_root/Contents/MacOS/mahayana"
    runtime="$bundle_root/Contents/Frameworks/libmahayana_runtime.dylib"
    ;;
  linux)
    cli="$bundle_root/mahayana"
    runtime="$bundle_root/lib/libmahayana_runtime.so"
    ;;
  *)
    echo "unsupported Mahayana bundle target: $target" >&2
    exit 2
    ;;
esac

if [ ! -x "$cli" ]; then
  echo "Bundled Mahayana CLI is missing or not executable: $cli" >&2
  exit 1
fi
if [ ! -f "$runtime" ]; then
  echo "Bundled Mahayana Runtime is missing: $runtime" >&2
  exit 1
fi

"$cli" help >/dev/null
smoke_home="$(mktemp -d)"
trap 'rm -rf "$smoke_home"' EXIT
status_json="$(MAHAYANA_HOME="$smoke_home" "$cli" status)"
grep -Eq '"model"[[:space:]]*:[[:space:]]*"deepseek-chat"' <<<"$status_json"
grep -Eq '"modelProvider"[[:space:]]*:[[:space:]]*"first-party-dacheng"' <<<"$status_json"
grep -Eq '"remoteAgentEnabled"[[:space:]]*:[[:space:]]*false' <<<"$status_json"

echo "Verified bundled Mahayana CLI and Runtime in $bundle_root"
