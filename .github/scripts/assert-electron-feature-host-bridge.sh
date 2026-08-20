#!/usr/bin/env bash
set -euo pipefail

main="desktop/electron/main.cjs"
preload="desktop/electron/preload.cjs"
edge="desktop/electron/mahayana-edge.cjs"
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
  grep -Fq "'$method'" "$edge" || { echo "Mahayana edge descriptor missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$app_host" || { echo "Rust app host dispatch missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$electron_transport" || { echo "Electron frontend transport missing $method" >&2; exit 1; }
done

grep -Fq "defineEdge('mahayana-host'" "$edge" || { echo "Mahayana edge descriptor is not declared" >&2; exit 1; }
grep -Fq "['runtime-event']" "$edge" || { echo "Mahayana runtime-event declaration is missing" >&2; exit 1; }

grep -Fq 'const allowedHostMethods = new Set(Object.keys(MAHAYANA_EDGE.methods));' "$main" || {
  echo "Electron main does not derive its compatibility allowlist from MAHAYANA_EDGE" >&2
  exit 1
}
grep -Fq 'Object.keys(MAHAYANA_EDGE.methods).map((method)' "$main" || {
  echo "Electron main does not derive edge handlers from MAHAYANA_EDGE" >&2
  exit 1
}
grep -Fq 'serveMainEdge(ipcMain, MAHAYANA_EDGE, handlers' "$main" || {
  echo "Electron main does not serve MAHAYANA_EDGE through the shared edge runtime" >&2
  exit 1
}
grep -Fq "host.request('feature.receive', {})" "$main" || {
  echo "Electron main runtime event pump is missing" >&2
  exit 1
}
grep -Fq "mahayanaEdgeServer.emit(win.webContents, 'runtime-event', event)" "$main" || {
  echo "Electron main runtime event push is missing" >&2
  exit 1
}

if grep -Eq "require\(['\"]\./" "$preload"; then
  echo "Electron sandbox preload must not require local modules" >&2
  exit 1
fi
grep -Fq "const MAHAYANA_EDGE = 'mahayana-host';" "$preload" || {
  echo "Electron preload Mahayana edge name is missing" >&2
  exit 1
}
grep -Fq 'return `fabushi-edge:${edge}:call:${method}`;' "$preload" || {
  echo "Electron preload edge call-channel construction is missing" >&2
  exit 1
}
grep -Fq "contextBridge.exposeInMainWorld('mahayana', mahayana)" "$preload" || {
  echo "Electron preload does not expose the Mahayana bridge" >&2
  exit 1
}
grep -Fq 'return subscribeEdge(MAHAYANA_EDGE, MAHAYANA_RUNTIME_EVENT, listener);' "$preload" || {
  echo "Electron preload runtime-event subscription is missing" >&2
  exit 1
}
grep -Fq "contextBridge.exposeInMainWorld('fabushiNative'" "$preload" || {
  echo "Electron preload native desktop bridge is missing" >&2
  exit 1
}

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
  echo "Canonical Electron renderer does not reuse the shared HostClient" >&2
  exit 1
}
grep -Fq '<HostClient />' "$desktop_renderer" || {
  echo "Canonical Electron renderer does not render the shared browser HostClient" >&2
  exit 1
}
if grep -Eq 'PluginRuntimeApp|desktop-mode-switch|open-plugin-runtime|open-agent-host' "$desktop_renderer"; then
  echo "Canonical Electron renderer must not wrap the shared browser UI in a second desktop shell" >&2
  exit 1
fi
grep -Fq "cfg(not(any(target_os = \"ios\", target_os = \"android\")))" "$app_host_manifest" || {
  echo "Desktop Feature Host dependencies are not isolated from mobile app-host builds" >&2
  exit 1
}

echo "Electron Feature Host bridge contract is complete."
