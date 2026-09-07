# 2026-09-07 Desktop updater automatic quit regression

## User-observed behavior

A packaged desktop client detected a newer version and accepted the update click, but the running Fabushi process did not terminate automatically. The replacement only completed after the user manually quit the application; the next launch was the new version.

## Diagnosis

This is a continuation of FCM-011 desktop updater reliability.

Fabushi intentionally treats a normal desktop window close as background persistence: the `BrowserWindow` `close` listener calls `event.preventDefault()` and hides the window. During an update, `electron-updater` / Squirrel.Mac also closes the application as part of `quitAndInstall`. The update path already marks `desktopUpdateInstallationInProgress` so `before-quit` cleanup will not block installation, but the earlier window-close interception can still turn the updater-owned close into a hide-to-background operation.

Upstream reference inspected before implementation: `electron-userland/electron-builder` `MacUpdater.ts` (MIT). Its macOS `quitAndInstall` path ultimately calls Electron's native updater / `app.quit()` and expects the app to be allowed to terminate after Squirrel has staged the replacement.

## Required behavior

- One update click may download/stage the release and then terminate Fabushi automatically so Squirrel can replace and relaunch it.
- Normal user window close continues to hide Fabushi in the background.
- If native `quitAndInstall` throws synchronously, the one-shot updater-close bypass must be removed.
- Existing visible updater error/status handling remains authoritative for failed download or install preparation.

## Verification

A focused Node regression covers normal close interception, updater-owned close bypass, and cleanup after a synchronous updater failure. Packaged exact-main update/relaunch verification remains required by the FCM-011 updater acceptance gate.
