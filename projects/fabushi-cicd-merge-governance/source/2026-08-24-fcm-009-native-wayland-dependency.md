# 2026-08-24 — FCM-009 native shared-host Linux dependency repair

## Trigger

Canonical `main@bc4aa98370fe719abee35f50d7f0bec36bf8bc71` entered the new post-main loop. Android and iOS simulated-user jobs passed, but `Native mobile result` failed because the shared Rust-host clippy job could not build `wayland-sys`: `pkg-config` could not find `wayland-client.pc`. This blocked Release publication exactly as designed.

## Upstream / proven reference review

- Upstream Smithay `wayland-rs` exposes a system-client feature backed by the system Wayland C implementation.
- Ubuntu 24.04 `libwayland-dev` is the canonical development package and ships `wayland-client.pc` plus the Wayland client headers/library.
- Fabushi's already-green Electron Linux Host job already installs the complete native development dependency set needed by the same Rust graph: `pkg-config`, clang, XCB/XRandR/XFixes, DBus, PipeWire, Wayland, xkbcommon, EGL and GBM development packages.

## Decision

Do not weaken clippy, disable Wayland features, or skip the shared-host gate. Reuse the known-good Electron native dependency bootstrap in the Native mobile shared-host contract job. This keeps the actual Rust graph unchanged and fixes only the CI runner environment.

## Acceptance

- Native mobile shared-host clippy/test passes on Ubuntu.
- Android and iOS simulated-user gates remain green.
- `Native mobile result` becomes green for the exact canonical main SHA.
- Post-main Release remains blocked until this is true.
