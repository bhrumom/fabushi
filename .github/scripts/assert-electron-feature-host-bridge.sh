#!/usr/bin/env bash
set -euo pipefail

main="desktop/electron/main.cjs"
preload="desktop/electron/preload.cjs"
app_host="third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs"
electron_transport="frontend/apps/web/src/lib/mahayana-host/electron-transport.ts"
mock_transport="frontend/apps/web/src/lib/mahayana-host/mock-transport.ts"
host_client="frontend/apps/web/src/app/host/host-client.tsx"
desktop_renderer="desktop/src/main.tsx"
app_host_manifest="third_party/mahayana/mahayana-rs/mahayana-app-host/Cargo.toml"

methods=(
  feature.info
  feature.execute
  feature.receive
  feature.approval.resolve
  feature.interrupt
  feature.auth.status
  feature.auth.providers
  feature.auth.passwordLogin
  feature.auth.oauthStart
  feature.auth.oauthPoll
  feature.auth.logout
)

for method in "${methods[@]}"; do
  grep -Fq "'$method'" "$main" || { echo "Electron main whitelist missing $method" >&2; exit 1; }
  grep -Fq "'$method'" "$preload" || { echo "Electron preload whitelist missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$app_host" || { echo "Rust app host dispatch missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$electron_transport" || { echo "Electron frontend transport missing $method" >&2; exit 1; }
done

grep -Fq 'new ElectronMahayanaHostTransport()' "$mock_transport" || {
  echo "Browser host selector does not delegate to Electron transport" >&2
  exit 1
}
grep -Fq 'isElectronMahayanaHostAvailable() || isTauriMahayanaHostAvailable()' "$host_client" || {
  echo "Host UI does not select production mode for Electron" >&2
  exit 1
}
grep -Fq "ipcMain.handle('fabushi:window-focused'" "$main" || { echo "window focus IPC missing" >&2; exit 1; }
grep -Fq "ipcMain.handle('fabushi:open-system-settings'" "$main" || { echo "system settings IPC missing" >&2; exit 1; }
grep -Fq 'openSystemSettings(pane)' "$preload" || { echo "system settings preload bridge missing" >&2; exit 1; }
grep -Fq 'windowFocused()' "$preload" || { echo "window focus preload bridge missing" >&2; exit 1; }
grep -Fq "import HostClient from '../../frontend/apps/web/src/app/host/host-client'" "$desktop_renderer" || {
  echo "Canonical Electron renderer does not reuse the full migrated HostClient" >&2
  exit 1
}
grep -Fq '<HostClient />' "$desktop_renderer" || {
  echo "Canonical Electron renderer does not render the shared Tauri/Grok HostClient" >&2
  exit 1
}
if grep -Eq 'PluginRuntimeApp|desktop-mode-switch|open-plugin-runtime|open-agent-host' "$desktop_renderer"; then
  echo "Canonical Electron renderer must not wrap the shared Tauri/Grok UI in a second desktop shell" >&2
  exit 1
fi
grep -Fq "cfg(not(any(target_os = \"ios\", target_os = \"android\")))" "$app_host_manifest" || {
  echo "Desktop Feature Host dependencies are not isolated from mobile app-host builds" >&2
  exit 1
}

echo "Electron Feature Host bridge contract is complete."
