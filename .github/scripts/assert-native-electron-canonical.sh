#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'release architecture check: %s\n' "$*" >&2; exit 1; }

# FCM-025: this script is an artifact-construction integrity check only.
# It deliberately does not run product tests, test suites, simulators,
# emulators, E2E journeys, smoke tests, or version-mirror quality gates.
# Test/beta publication is sourced from app-version.json and exact protected-main
# ancestry; store/build workflows may stamp platform package metadata in their
# runner workspaces without requiring repository-wide mirror rewrites first.

test -f app-version.json || fail 'canonical app-version.json is missing'
test -f desktop/package.json || fail 'desktop/package.json is missing'
test -f desktop/electron/main.cjs || fail 'Electron main process is missing'
test -f mobile/android/app/src/main/java/com/ombhrum/fabushi/MainActivity.kt || fail 'Compose MainActivity is missing'
test -f mobile/ios/Fabushi/FabushiApp.swift || fail 'SwiftUI app entry is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host/Cargo.toml || fail 'shared Rust app host core is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host-desktop/Cargo.toml || fail 'Electron Rust sidecar wrapper is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host-mobile/Cargo.toml || fail 'native mobile Rust FFI wrapper is missing'
test -f .github/workflows/electron-desktop.yml || fail 'no-test desktop release workflow is missing'
test -f .github/workflows/mobile-test-delivery.yml || fail 'no-test mobile release dispatcher is missing'
test -f .github/workflows/google-play-delivery.yml || fail 'Android store delivery workflow is missing'
test -f .github/workflows/apple-store-delivery.yml || fail 'Apple store delivery workflow is missing'

python3 - <<'PY'
import json
import re
from pathlib import Path
value = json.loads(Path('app-version.json').read_text(encoding='utf-8'))
version = str(value.get('version', '')).strip()
if not re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?', version):
    raise SystemExit(f'invalid canonical semantic version: {version!r}')
for key in ('androidVersionCode', 'iosBuildNumber'):
    raw = str(value.get(key, '')).strip()
    if not raw.isdigit() or int(raw) <= 0:
        raise SystemExit(f'invalid {key}: {raw!r}')
print(f'canonical release metadata: {version} android={value["androidVersionCode"]} ios={value["iosBuildNumber"]}')
PY

grep -q '"electron"' desktop/package.json || fail 'desktop does not declare Electron'
grep -q 'androidx.compose' mobile/android/app/build.gradle || fail 'Android canonical UI is not Compose'
grep -q 'SwiftUI' mobile/ios/Fabushi/FabushiApp.swift || fail 'iOS canonical UI is not SwiftUI'

printf '%s\n' 'Canonical Electron + native SwiftUI/Compose + shared Rust Host release structure is present; no product tests were run.'
