#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'architecture gate: %s\n' "$*" >&2; exit 1; }

test -f desktop/package.json || fail 'desktop/package.json is missing'
test -f desktop/electron/main.cjs || fail 'Electron main process is missing'
test -f mobile/android/app/src/main/java/com/ombhrum/fabushi/MainActivity.kt || fail 'Compose MainActivity is missing'
test -f mobile/ios/Fabushi/FabushiApp.swift || fail 'SwiftUI app entry is missing'
test -f third_party/mahayana/mahayana-rs/mahayana-app-host/Cargo.toml || fail 'shared Rust app host is missing'
test -f app-version.json || fail 'canonical app-version.json is missing'

grep -q '"electron"' desktop/package.json || fail 'desktop does not declare Electron'
grep -q 'contextIsolation: true' desktop/electron/main.cjs || fail 'Electron contextIsolation is not enforced'
grep -q 'nodeIntegration: false' desktop/electron/main.cjs || fail 'Electron nodeIntegration must remain disabled'
grep -q 'sandbox: true' desktop/electron/main.cjs || fail 'Electron renderer sandbox is not enforced'
grep -q 'androidx.compose' mobile/android/app/build.gradle || fail 'Android canonical UI is not Compose'
grep -q 'SwiftUI' mobile/ios/Fabushi/FabushiApp.swift || fail 'iOS canonical UI is not SwiftUI'
node - <<'NODE'
const fs = require('fs');
const canonical = JSON.parse(fs.readFileSync('app-version.json', 'utf8')).version;
const desktop = JSON.parse(fs.readFileSync('desktop/package.json', 'utf8')).version;
const mobile = JSON.parse(fs.readFileSync('mobile/package.json', 'utf8')).version;
if (desktop !== canonical || mobile !== canonical) {
  console.error(`version drift: canonical=${canonical} desktop=${desktop} mobile=${mobile}`);
  process.exit(1);
}
NODE

if grep -Eq '"@tauri-apps/|"@capacitor/' mobile/package.json desktop/package.json; then
  fail 'Tauri/Capacitor dependencies cannot return to canonical app packages'
fi
if grep -Eq "project\(':capacitor|apply from:.*capacitor" mobile/android/settings.gradle mobile/android/app/build.gradle; then
  fail 'Capacitor cannot return to the canonical Android project'
fi
if grep -Eq 'npm run tauri|tauri android|tauri ios|mobile/src-tauri' \
  .github/workflows/desktop-installers.yml .github/workflows/native-mobile.yml .github/workflows/android-real-device-e2e.yml 2>/dev/null; then
  fail 'canonical desktop/mobile workflows cannot invoke Tauri'
fi

printf '%s\n' 'Electron desktop + native SwiftUI/Compose + shared Rust Host is the canonical application architecture.'
