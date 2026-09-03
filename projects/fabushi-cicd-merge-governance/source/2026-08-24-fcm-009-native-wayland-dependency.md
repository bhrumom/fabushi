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

## Merge-queue blocker discovered during repair

The first merge-queue group for PR #2083 (`983680ab3290f7d0b48d7f5a59382376028cb023`) emitted two immediate failed workflow runs with **zero jobs**:

- `32679156035` — `.github/workflows/fab-p0001-m3-kick-driver.yml`
- `32679155565` — `.github/workflows/fab-p0001-m3-unread-patch-driver.yml`

Both files are obsolete one-shot M3 recovery drivers: one checks out the stale `fix/fab-p0001-m3-e2e-closure` branch and hard-codes a historical failed job ID; the other is an issue-comment patch driver for the already superseded #2022 closure path. They are not production CI and have no remaining owner/reference in project records. Under the repository merge-queue `ALLGREEN` policy their synthetic queue failures can prevent the actual `CI result` merge-group validation from completing.

Decision: remove both obsolete one-shot driver workflow files instead of weakening the merge queue. Canonical reusable messaging/Electron/Native gates remain unchanged.
