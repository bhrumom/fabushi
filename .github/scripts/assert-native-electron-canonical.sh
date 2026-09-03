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
for workflow in release-desktop-platform.yml release-macos.yml release-windows.yml release-linux.yml native-android-release.yml release-ios.yml; do
  test -f ".github/workflows/$workflow" || fail "platform release workflow $workflow is missing"
done
test -f .github/workflows/native-electron-release.yml || fail 'disabled legacy combined release marker is missing'
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
import re
from pathlib import Path

canonical_data = json.loads(Path('app-version.json').read_text(encoding='utf-8'))
canonical = str(canonical_data.get('version', '')).strip()
if not re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?', canonical):
    raise SystemExit(f'invalid canonical semantic version: {canonical!r}')

def package_version(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))['version']

def lock_root_version(path):
    document = json.loads(Path(path).read_text(encoding='utf-8'))
    return document['packages']['']['version']

versions = {
    'desktop/package.json': package_version('desktop/package.json'),
    'desktop/package-lock.json': lock_root_version('desktop/package-lock.json'),
    'mobile/package.json': package_version('mobile/package.json'),
    'mobile/package-lock.json': lock_root_version('mobile/package-lock.json'),
}
drift = {path: version for path, version in versions.items() if version != canonical}
if drift:
    raise SystemExit(f'version drift: canonical={canonical} values={drift}')

ios_project = Path('mobile/ios/project.yml').read_text(encoding='utf-8')
marketing_match = re.search(r'^\s*MARKETING_VERSION:\s*[\'"]?([^\s\'"]+)', ios_project, re.MULTILINE)
if not marketing_match or marketing_match.group(1) != canonical:
    observed = marketing_match.group(1) if marketing_match else '<missing>'
    raise SystemExit(f'iOS marketing version drift: canonical={canonical} project={observed}')
ios_build_number = str(canonical_data.get('iosBuildNumber', '')).strip()
if not re.fullmatch(r'\d+', ios_build_number):
    raise SystemExit(f'invalid canonical iOS build number: {ios_build_number!r}')
ios_build_match = re.search(r'^\s*CURRENT_PROJECT_VERSION:\s*[\'"]?([^\s\'"]+)', ios_project, re.MULTILINE)
if not ios_build_match or ios_build_match.group(1) != ios_build_number:
    observed = ios_build_match.group(1) if ios_build_match else '<missing>'
    raise SystemExit(f'iOS build number drift: canonical={ios_build_number} project={observed}')
PY

if grep -Eq '"@tauri-apps/|"@capacitor/' mobile/package.json desktop/package.json; then
  fail 'Tauri/Capacitor dependencies cannot return to canonical app packages'
fi
if grep -Eq "project\(':capacitor|apply from:.*capacitor" mobile/android/settings.gradle mobile/android/app/build.gradle; then
  fail 'Capacitor cannot return to the canonical Android project'
fi
if grep -Eq 'npm run tauri|tauri android|tauri ios|mobile/src-tauri' \
  .github/workflows/electron-desktop.yml .github/workflows/native-mobile.yml .github/workflows/release-desktop-platform.yml .github/workflows/release-macos.yml .github/workflows/release-windows.yml .github/workflows/release-linux.yml .github/workflows/native-android-release.yml .github/workflows/release-ios.yml; then
  fail 'canonical desktop/mobile workflows cannot invoke Tauri'
fi

printf '%s\n' 'Electron desktop + native SwiftUI/Compose + shared Rust Host is the canonical application architecture.'
