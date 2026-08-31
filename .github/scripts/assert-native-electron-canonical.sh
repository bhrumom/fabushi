#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'architecture gate: %s\n' "$*" >&2; exit 1; }

test -f desktop/package.json || fail 'desktop/package.json is missing'
test -f desktop/electron/main.cjs || fail 'Electron main process is missing'
test -f mobile/android/app/src/main/java/com/ombhrum/fabushi/MainActivity.kt || fail 'Compose MainActivity is missing'
test -f mobile/ios/Fabushi/FabushiApp.swift || fail 'SwiftUI app entry is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host/Cargo.toml || fail 'shared Rust app host core is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host-desktop/Cargo.toml || fail 'Electron Rust sidecar wrapper is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host-mobile/Cargo.toml || fail 'native mobile Rust FFI wrapper is missing'
test -f app-version.json || fail 'canonical app-version.json is missing'
test -f .github/workflows/electron-desktop.yml || fail 'Electron desktop quality workflow is missing'
test -f .github/workflows/native-mobile.yml || fail 'native mobile quality workflow is missing'
test -f .github/workflows/native-electron-release.yml || fail 'native Electron release workflow is missing'
test -f .github/workflows/google-play-delivery.yml || fail 'native Android Google Play delivery workflow is missing'
test -x .github/scripts/macos-codesign-wrapper/codesign || fail 'secure-timestamp codesign wrapper is missing or not executable'
bash -n .github/scripts/macos-codesign-wrapper/codesign || fail 'secure-timestamp codesign wrapper has invalid shell syntax'
grep -q 'Timestamp=' .github/scripts/macos-codesign-wrapper/codesign || fail 'codesign wrapper must verify the secure Timestamp field'
grep -q 'GITHUB_PATH' .github/scripts/build-offline-asr-engine.mjs || fail 'macOS build must install the codesign wrapper for later signing steps'

grep -q '"electron"' desktop/package.json || fail 'desktop does not declare Electron'
grep -q 'mahayana-app-host-desktop' desktop/package.json || fail 'Electron must build the desktop-only Rust sidecar wrapper'
grep -q 'contextIsolation: true' desktop/electron/main.cjs || fail 'Electron contextIsolation is not enforced'
grep -q 'nodeIntegration: false' desktop/electron/main.cjs || fail 'Electron nodeIntegration must remain disabled'
grep -q 'sandbox: true' desktop/electron/main.cjs || fail 'Electron renderer sandbox is not enforced'
grep -q 'androidx.compose' mobile/android/app/build.gradle || fail 'Android canonical UI is not Compose'
grep -q 'SwiftUI' mobile/ios/Fabushi/FabushiApp.swift || fail 'iOS canonical UI is not SwiftUI'
python3 - <<'PY'
import json
from pathlib import Path

canonical = json.loads(Path('app-version.json').read_text(encoding='utf-8'))['version']
desktop = json.loads(Path('desktop/package.json').read_text(encoding='utf-8'))['version']
mobile = json.loads(Path('mobile/package.json').read_text(encoding='utf-8'))['version']
if desktop != canonical or mobile != canonical:
    raise SystemExit(f'version drift: canonical={canonical} desktop={desktop} mobile={mobile}')
PY

if grep -Eq '"@tauri-apps/|"@capacitor/' mobile/package.json desktop/package.json; then
  fail 'Tauri/Capacitor dependencies cannot return to canonical app packages'
fi
if grep -Eq "project\(':capacitor|apply from:.*capacitor" mobile/android/settings.gradle mobile/android/app/build.gradle; then
  fail 'Capacitor cannot return to the canonical Android project'
fi
if grep -Eq 'npm run tauri|tauri android|tauri ios|mobile/src-tauri' \
  .github/workflows/electron-desktop.yml .github/workflows/native-mobile.yml .github/workflows/native-electron-release.yml; then
  fail 'canonical desktop/mobile workflows cannot invoke Tauri'
fi

printf '%s\n' 'Electron desktop + native SwiftUI/Compose + shared Rust Host is the canonical application architecture.'
