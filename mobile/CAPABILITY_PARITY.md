# Fabushi Native Capability Parity

This document tracks the migration target after retiring the WebView application shell.

## Platform contract

| Capability | Desktop | Android | iOS | Shared owner |
|---|---|---|---|---|
| Main UI | Electron + React | Jetpack Compose | SwiftUI | platform shell |
| Marketplace API | Electron IPC | JNI | C ABI | `mahayana-app-host` |
| Plugin install/verify | Electron IPC | JNI | C ABI | Rust host |
| Plugin permissions | Electron IPC | JNI | C ABI | Rust host |
| Portable JS runtime | Rust sidecar | Rust `.so` | Rust staticlib | Rust host |
| Secure product session | Rust | Rust | Rust | `mahayana-product` |
| Deep links | Electron main | Android intent | SwiftUI/OpenURL | platform shell + Rust payload validation |
| File picker | Electron dialog | Activity Result API | `fileImporter`/UIDocumentPicker | platform shell |
| Local notifications | Electron Notification | Android notification API | UserNotifications | platform shell |
| External HTTPS URL | Electron shell allowlist | Android intent allowlist | `openURL` allowlist | platform shell |
| Biometrics | OS native API | BiometricPrompt | LocalAuthentication | platform shell |
| Push token | OS/native adapter | FCM | APNs | platform shell -> backend |
| Camera/photos | OS/native adapter | CameraX / Photo Picker | AVFoundation / PhotosUI | platform shell |
| Location/maps | OS/native adapter | Android location/maps | CoreLocation/MapKit | platform shell |
| Share surface | Electron OS integration | Android Sharesheet | ShareLink/Share Extension | platform shell |

## Implemented by this migration

- Electron desktop shell and hardened preload/main IPC boundary.
- Native Compose Android application shell.
- Native SwiftUI iOS application shell.
- Shared Rust host callable from desktop NDJSON IPC, Android JNI, and iOS C ABI.
- Marketplace browse, release metadata, plugin installation, permission state, compatibility checks, portable JS runtime start/stop/tool calls in the shared host.
- Stable semantic/accessibility identifiers for core UI automation.
- PR/main emulator/simulator gates and Android physical-device testing.
- Native production APK/AAB/IPA packaging workflows.

## Follow-up native feature adapters

The following product features must stay native if/when the product surface requires them. They must not be implemented by restoring a WebView shell:

- Sign in with Apple / Google Sign-In.
- APNs/FCM registration and notification routing.
- Camera/video capture and media picker.
- Background execution and background transfers.
- OS share extensions / Android sharesheet receive flow.
- Widgets / Live Activities / Android widgets.
- Siri/App Intents and Android intents/shortcuts.
- Native maps/location.
- Audio session, microphone, realtime voice, screen sharing.
- StoreKit / Play Billing when native billing is required.

Each adapter needs three things before release: a narrow platform interface, deterministic unit/contract tests where possible, and at least one emulator/simulator or physical-device E2E path for the user-visible flow.

## Definition of parity

A capability is considered migrated only when:

1. the user-visible flow exists in the native shell;
2. product/business policy is shared in Rust or a platform-neutral service rather than duplicated without reason;
3. accessibility/semantic identifiers exist for testable controls;
4. failure and permission-denied states are handled explicitly;
5. CI has objective evidence (unit/integration/UI test, build artifact, or physical-device result);
6. production release does not depend on any retired shell artifact.
