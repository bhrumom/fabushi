#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/assert-native-electron-canonical.sh" "$@"
