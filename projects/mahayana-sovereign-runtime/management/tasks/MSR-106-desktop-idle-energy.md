# MSR-106 — Desktop idle/background energy

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-106
- **Status:** in-progress
- **Started:** 2026-08-24T13:52:00+08:00
- **Updated:** 2026-08-24T14:00:00+08:00
- **Branch:** `fix/desktop-updater-idle-energy`

## Objective
Eliminate the Mahayana desktop runtime busy-poll that keeps Fabushi near the top of macOS battery usage while the app is idle/backgrounded, without adding latency to real runtime events.

## Diagnosed evidence
- The installed Fabushi `1.0.2` process had remained alive for over five hours on macOS.
- With the app hidden, renderer/GPU usage fell to approximately zero, but `mahayana-app-host` remained about `21.6% CPU` and the Electron main process about `0.9% CPU`.
- `desktop/electron/main.cjs` repeatedly calls `feature.receive`; when no event is returned it sleeps only 10 ms.
- Production `mahayana-feature-host::receive_production` waits only 1 ms on `crossbeam_channel::recv_timeout`, causing roughly tens of IPC wakeups per second while completely idle.
- A process sample captured `feature_receive -> crossbeam_channel::Receiver::recv_timeout` as the active host stack.

## Open-source-first baseline
- Existing `crossbeam-channel` (MIT/Apache-2.0) is already the runtime event primitive and natively supports blocking `recv_timeout`; no polling framework is needed.
- Proven event-loop pattern: block the first receive with a bounded timeout, wake immediately when data arrives, then drain already queued events without another long wait.
- Decision: reuse the existing channel's blocking semantics; no new dependency.

## Implementation
- `feature.receive` now accepts a bounded `timeoutMs`; the Electron event pump requests a 500 ms long poll, while existing direct/test callers remain non-blocking by default.
- The production controller blocks only for the first runtime event, returning immediately when data arrives; subsequent iterations use a zero timeout to drain queued/translatable events without adding streaming latency.
- Electron remains responsive to runtime events while idle wakeups collapse from approximately ~90 polls/sec to about ~2 polls/sec.

## Acceptance
- Hidden/background idle `mahayana-app-host` no longer burns double-digit CPU.
- Runtime events still wake immediately rather than waiting for the full timeout.
- Existing feature-host/runtime tests pass.
- PR passes required CI, protected merge queue, post-main packaged E2E/Release, and canonical-main readback.

## Local verification before PR
- Hidden installed 1.0.2 baseline: `mahayana-app-host` approximately 21.6% CPU while renderer/GPU fell near zero.
- Process sample showed the host active in `feature_receive -> crossbeam_channel::Receiver::recv_timeout`.
- `node --test desktop/electron/host-process.test.cjs` — 5/5 pass.
- Electron Feature Host bridge contract — pass with explicit `{ timeoutMs: 500 }` and Rust `receive_with_timeout` forwarding.
- Rust formatting/build validation is intentionally delegated to GitHub Actions because the repository's canonical native toolchain/build evidence is CI-hosted.

## Current evidence / next gate
Implementation pending exact-head CI, protected merge, exact-main packaged delivery, then target-Mac hidden-idle CPU remeasurement.
