# GBF-202 Evidence — preload / IPC contract

- Dedicated `window.mahayana`, `window.fabushiNative`, and shell-only `window.fabushi` bridges are separated.
- Contract version `1` is explicit in preload and shared edge descriptors.
- Host transport binds to `window.mahayana.contractVersion === 1`; it no longer routes through `window.fabushi.invoke`.
- Generic `ipcMain.handle('fabushi:host')` is removed and guarded against reintroduction by CI.
- `edge-ipc.test.cjs` verifies declared-method-only client construction, trust denial, missing handler, stable failures, event allowlist, disposal and subscriptions.
