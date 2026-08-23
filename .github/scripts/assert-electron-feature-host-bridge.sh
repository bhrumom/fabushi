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
desktop_shell=""
app_host_manifest="third_party/mahayana/mahayana-rs/mahayana-app-host/Cargo.toml"

if grep -Fq "./messaging-shell-v2" "$desktop_renderer"; then
  desktop_shell="desktop/src/messaging-shell-v2.tsx"
elif grep -Fq "./messaging-shell" "$desktop_renderer"; then
  desktop_shell="desktop/src/messaging-shell.tsx"
fi

methods=(
  feature.info
  feature.execute
  feature.receive
  feature.approval.resolve
  feature.interrupt
  feature.auth.status
  feature.auth.providers
  feature.auth.passwordLogin
  feature.auth.browserStart
  feature.auth.browserPoll
  feature.auth.browserCancel
  feature.auth.browserReopen
  feature.auth.oauthStart
  feature.auth.oauthPoll
  feature.auth.logout
  marketplace.browse
  marketplace.release
  plugin.install
  plugin.uninstall
  plugin.active
  plugin.listInstalled
  plugin.uiDocument
)

for method in "${methods[@]}"; do
  grep -Fq "'$method'" "$edge" || { echo "Mahayana edge descriptor missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$app_host" || { echo "Rust app host dispatch missing $method" >&2; exit 1; }
  grep -Fq "\"$method\"" "$electron_transport" || { echo "Electron frontend transport missing $method" >&2; exit 1; }
done

grep -Fq "defineEdge('mahayana-host'" "$edge" || { echo "Mahayana edge descriptor is not declared" >&2; exit 1; }
grep -Fq "['runtime-event']" "$edge" || { echo "Mahayana runtime-event declaration is missing" >&2; exit 1; }
if grep -Fq "ipcMain.handle('fabushi:host'" "$main"; then
  echo "Electron main must not expose the retired generic fabushi:host IPC channel" >&2
  exit 1
fi
grep -Fq 'Object.keys(MAHAYANA_EDGE.methods).map((method)' "$main" || { echo "Electron main does not derive edge handlers from MAHAYANA_EDGE" >&2; exit 1; }
grep -Fq 'serveMainEdge(ipcMain, MAHAYANA_EDGE, handlers' "$main" || { echo "Electron main does not serve MAHAYANA_EDGE through the shared edge runtime" >&2; exit 1; }
grep -Fq "host.request('feature.receive', {})" "$main" || { echo "Electron main runtime event pump is missing" >&2; exit 1; }
grep -Fq "mahayanaEdgeServer.emit(win.webContents, 'runtime-event', event)" "$main" || { echo "Electron main runtime event push is missing" >&2; exit 1; }

if grep -Eq "require\(['\"]\./" "$preload"; then
  echo "Electron sandbox preload must not require local modules" >&2
  exit 1
fi
grep -Fq "const MAHAYANA_EDGE = 'mahayana-host';" "$preload" || { echo "Electron preload Mahayana edge name is missing" >&2; exit 1; }
grep -Fq 'const EDGE_CONTRACT_VERSION = 1;' "$preload" || { echo "Electron preload edge contract version is missing" >&2; exit 1; }
grep -Fq 'contractVersion: EDGE_CONTRACT_VERSION' "$preload" || { echo "Electron preload does not expose the edge contract version" >&2; exit 1; }
grep -Fq 'return `fabushi-edge:${edge}:call:${method}`;' "$preload" || { echo "Electron preload edge call-channel construction is missing" >&2; exit 1; }
grep -Fq "contextBridge.exposeInMainWorld('mahayana', mahayana)" "$preload" || { echo "Electron preload does not expose the Mahayana bridge" >&2; exit 1; }
grep -Fq 'return subscribeEdge(MAHAYANA_EDGE, MAHAYANA_RUNTIME_EVENT, listener);' "$preload" || { echo "Electron preload runtime-event subscription is missing" >&2; exit 1; }
grep -Fq "contextBridge.exposeInMainWorld('fabushiNative'" "$preload" || { echo "Electron preload native desktop bridge is missing" >&2; exit 1; }

grep -Fq 'new ElectronMahayanaHostTransport()' "$mock_transport" || {
  echo "Browser host selector does not delegate to Electron transport" >&2
  exit 1
}
grep -Fq 'isElectronMahayanaHostAvailable()' "$host_client" || {
  echo "Host UI does not select production mode for Electron" >&2
  exit 1
}
grep -Fq 'window.mahayana?.contractVersion === ELECTRON_EDGE_CONTRACT_VERSION' "$electron_transport" || { echo "Electron transport does not bind to the versioned Mahayana bridge" >&2; exit 1; }
if grep -Fq 'window.fabushi?.invoke' "$electron_transport"; then
  echo "Electron transport must not route Host calls through the generic Fabushi shell facade" >&2
  exit 1
fi
grep -Fq "ipcMain.handle('fabushi:window-focused'" "$main" || { echo "window focus IPC missing" >&2; exit 1; }
grep -Fq "ipcMain.handle('fabushi:open-system-settings'" "$main" || { echo "system settings IPC missing" >&2; exit 1; }
grep -Fq 'openSystemSettings(pane)' "$preload" || { echo "system settings preload bridge missing" >&2; exit 1; }
grep -Fq 'windowFocused()' "$preload" || { echo "window focus preload bridge missing" >&2; exit 1; }

if grep -Fq "import HostClient from '../../frontend/apps/web/src/app/host/host-client'" "$desktop_renderer" && grep -Fq '<HostClient />' "$desktop_renderer"; then
  :
elif test -n "$desktop_shell" && test -f "$desktop_shell" \
  && grep -Fq "import HostClient from '../../frontend/apps/web/src/app/host/host-client'" "$desktop_shell" \
  && grep -Fq '<HostClient />' "$desktop_shell"; then
  :
else
  echo "Canonical Electron renderer does not reuse and render the shared HostClient directly or through the approved Messenger shell" >&2
  exit 1
fi

grep -Fq 'MahayanaProductClient::new_with_default_api_base_url' "$app_host" || { echo "Electron Rust app host must keep product credentials inside its app-data Feature Host root" >&2; exit 1; }
if grep -Fq 'MahayanaProductClient::default()' "$app_host"; then
  echo "Electron Rust app host must not probe the shared Mahayana container during startup" >&2
  exit 1
fi
if test -n "$desktop_shell" && grep -Fq 'defaultMiniApps' "$desktop_shell"; then
  echo "Unified Messenger must discover Mini Apps from the online marketplace, not a bundled defaultMiniApps registry" >&2
  exit 1
fi

for file in "$desktop_renderer" ${desktop_shell:+"$desktop_shell"}; do
  if grep -Eq 'PluginRuntimeApp|desktop-mode-switch|open-plugin-runtime|open-agent-host' "$file"; then
    echo "Canonical Electron renderer must not expose the retired PluginRuntime surface: $file" >&2
    exit 1
  fi
done
grep -Fq "cfg(not(any(target_os = \"ios\", target_os = \"android\")))" "$app_host_manifest" || { echo "Desktop Feature Host dependencies are not isolated from mobile app-host builds" >&2; exit 1; }

echo "Electron Feature Host bridge contract is complete."
