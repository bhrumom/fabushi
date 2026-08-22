# Fabushi Electron + Native Mobile Migration

## Canonical architecture

Fabushi has one shared Rust product/runtime core and three platform UI shells:

```text
Mahayana Rust Host (mahayana-app-host)
├── Desktop: Electron 43 + React/TypeScript
├── Android: Kotlin + Jetpack Compose
└── iOS: Swift + SwiftUI
```

The previous WebView/Tauri/Capacitor mobile shell has been removed from the repository. `mobile/` contains only the native SwiftUI and Jetpack Compose applications plus their shared native package metadata.

## Desktop

`desktop/` is the canonical desktop application.

- Chromium/Electron provides a consistent renderer on macOS, Windows, and Linux.
- Privileged work runs outside the renderer.
- `nodeIntegration` is disabled.
- `contextIsolation`, renderer sandboxing, and `webSecurity` are required.
- The preload bridge exposes a small allowlisted API; it never exposes `ipcRenderer` or Node globals.
- All host IPC validates the sender and method allowlist.
- Arbitrary navigation/new windows are denied; external navigation is HTTPS-only.
- `mahayana-app-host` runs as a persistent Rust sidecar over newline-delimited JSON IPC.

## Android

`mobile/android/` is the canonical Android application.

- Kotlin + Jetpack Compose, no WebView application shell.
- Compose Semantics/TestTags are part of the UI contract for automation and accessibility.
- The shared Rust host is compiled as `libmahayana_app_host.so` with `cargo-ndk`.
- Kotlin reaches the Rust host through a small JNI boundary (`MahayanaHost`).
- Rust host state is persistent for the life of the ViewModel/host instance.
- Production builds use R8/resource shrinking and release signing supplied only by CI secrets.

## iOS

`mobile/ios/` is the canonical iOS application.

- Swift + SwiftUI, no WebView application shell.
- Accessibility identifiers are stable automation contracts.
- XcodeGen creates the `.xcodeproj` deterministically from `project.yml`; generated Xcode project files are not the source of truth.
- The shared Rust host is linked as a static library using the C ABI in `mobile/native/include/mahayana_app_host.h`.
- The Swift host keeps one native handle alive so runtime/plugin state is not recreated per request.
- App Store archives are signed/exported only in CI with certificate and provisioning-profile secrets.

## Shared Rust host

`third_party/mahayana/mahayana-rs/mahayana-app-host` owns product/runtime operations that previously lived behind shell-specific commands.

Current host methods include:

- `host.platform`
- `marketplace.browse`
- `marketplace.release`
- `plugin.install`
- `plugin.active`
- `plugin.permissions`
- `plugin.permission.grant`
- `plugin.permission.revoke`
- `plugin.compatibility`
- `runtime.start`
- `runtime.stop`
- `runtime.tools`

The desktop sidecar, Android JNI bridge, and iOS C bridge all call this same host API.

## Versioning

`app-version.json` is the only canonical application version source. Platform release build numbers may be raised by CI run number, but product semantic version comes from this file.

## Release paths

- Desktop quality/package gate: `.github/workflows/electron-desktop.yml`
- Native mobile PR/main gate: `.github/workflows/native-mobile.yml`
- Signed cross-platform release: `.github/workflows/native-electron-release.yml`
- Apple TestFlight/App Store delivery: `.github/workflows/apple-store-delivery.yml`
- Android Google Play delivery: `.github/workflows/google-play-delivery.yml`

No Flutter, Tauri, or Capacitor application build path remains in the canonical repository.

## Non-negotiable rules

1. Do not reintroduce WebView as the primary mobile UI.
2. Do not duplicate product/runtime policy in Swift, Kotlin, and TypeScript; keep it in the shared Rust host when practical.
3. Do not expose raw native/IPC objects to plugin or renderer code.
4. Automation locators must use semantics/accessibility/test IDs, never screen coordinates.
5. Production signing credentials live only in CI secrets.
6. A failed native/desktop gate blocks release; flaky retries are evidence collection, not a mechanism to turn failures green.
