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

"$cli" --help >/dev/null
smoke_home="$(mktemp -d)"
cleanup_smoke_home() {
  local attempt
  trap - ERR
  for ((attempt = 1; attempt <= 30; attempt++)); do
    rm -rf "$smoke_home" 2>/dev/null || true
    if [ ! -e "$smoke_home" ]; then
      return 0
    fi
    sleep 1
  done
  echo "warning: could not fully remove Mahayana smoke home: $smoke_home" >&2
  return 0
}
trap cleanup_smoke_home EXIT
status_json="$(MAHAYANA_HOME="$smoke_home" "$cli" status)"
grep -Eq '"model"[[:space:]]*:[[:space:]]*"deepseek-chat"' <<<"$status_json"
grep -Eq '"modelProvider"[[:space:]]*:[[:space:]]*"first-party-dacheng"' <<<"$status_json"
grep -Eq '"remoteAgentEnabled"[[:space:]]*:[[:space:]]*false' <<<"$status_json"

echo "Verified bundled Mahayana CLI and Runtime in $bundle_root"
