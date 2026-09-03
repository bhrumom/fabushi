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

## 2026-08-24 renderer/GPU continuation

A second target-Mac measurement with packaged `1.0.798` while ChatGPT was foreground and Fabushi merely sat behind it showed the remaining dominant drain: Fabushi GPU process about `60.9% CPU` and renderer about `22.5% CPU`, while the local ChatGPT benchmark was near-idle (main about `0.2%`, GPU service about `1.3%` in the sampled process view).

Root cause: the shared BotMark engine kept its global `requestAnimationFrame` clock alive whenever marks were intersection-visible, even when the Fabushi document had lost focus; CSS aura/breathe/orbit animations also continued. The energy fix therefore extends beyond Host long-polling:

- suspend the shared JS motion clock whenever the document is hidden or the Fabushi window is unfocused;
- set a document motion lifecycle marker so CSS BotMark compositor animations pause at the same boundary;
- resume immediately on focus/visibility return;
- cap focused shared motion dispatch to 30 FPS (slow organic avatar motion does not need 60+ attribute writes/sec);
- preserve `prefers-reduced-motion` and per-mark pause semantics.

Acceptance adds target-Mac background measurement after the packaged fix: renderer/GPU and `mahayana-app-host` must settle near idle rather than sustained double-digit CPU.

## 2026-09-03 current-main energy regression continuation

The user again reported severe desktop battery usage. Current-main inspection found that the avatar implementation had drifted from the intended shared-clock design: every `FabushiAvatarRuntime` instance owned its own `requestAnimationFrame` loop. A conversation/contact list with many animated Bot marks therefore registered many callbacks per display frame while the app was focused. Motion pause on blur/hidden still existed per mark, but the focused callback fan-out was unnecessarily expensive.

This round restores the intended energy architecture without trading UI latency for lower wakeups:

- `FabushiAvatarRuntime` now has one module-level shared frame scheduler for all live avatar instances;
- shared dispatch is capped at approximately 30 FPS using one timer + one animation-frame synchronization point rather than one continuous rAF loop per avatar;
- `BotMark` focus/visibility lifecycle is also shared, so the document has one `visibilitychange/focus/blur` subscription set rather than one set per avatar;
- all avatar subscribers still detach when motion is paused/reduced and the shared clock stops completely when subscriber count reaches zero;
- the Host event receive stays at the established bounded 500 ms long poll because the app-host request transport is serial. Extending it to tens of seconds would reduce wakeups by blocking auth/settings IPC and is therefore rejected;
- after every Host receive, Electron yields one main-loop turn before re-entering the bounded blocking receive, preserving renderer IPC fairness during streamed events.

New packaged acceptance: measure foreground idle and hidden/background renderer/GPU/app-host CPU/energy on the target Mac, verify the avatar runtime reports `data-frame-clock="shared-30fps"`, and compare against the previous double-digit renderer/GPU baseline. This task remains `in-progress` until the packaged measurement and exact-main release gate pass.
