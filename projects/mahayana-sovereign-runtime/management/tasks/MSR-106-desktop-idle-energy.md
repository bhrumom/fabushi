# MSR-106 — Desktop idle/background energy

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-106
- **Status:** in-progress
- **Started:** 2026-08-24T13:52:00+08:00
- **Updated:** 2026-09-07T20:39:00+08:00
- **Current Branch:** `fix/desktop-energy-ghost-white-release`
- **Visual/brand companion:** `GBF-509`

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
- Electron's official `backgroundThrottling` default is `true`; it throttles animations/timers when a page is backgrounded and participates in Page Visibility. The continuation keeps this platform default and adds a stricter application-level focus/visibility pause rather than disabling Chromium's throttling or adding another scheduler.
- Decision: reuse the existing channel, Electron/Chromium lifecycle and `requestAnimationFrame`; no new runtime dependency.

Reference: https://www.electronjs.org/docs/latest/api/structures/web-preferences

## Implementation
- `feature.receive` accepts a bounded `timeoutMs`; the Electron event pump requests a 500 ms long poll, while existing direct/test callers remain non-blocking by default.
- The production controller blocks only for the first runtime event, returning immediately when data arrives; subsequent iterations use a zero timeout to drain queued/translatable events without adding streaming latency.
- Electron remains responsive to runtime events while idle wakeups collapse from approximately ~90 polls/sec to about ~2 polls/sec.

## Acceptance
- Hidden/background idle `mahayana-app-host` no longer burns double-digit CPU.
- Runtime events still wake immediately rather than waiting for the full timeout.
- Renderer/GPU animation clocks stop when the Fabushi document is hidden or the window is unfocused.
- Ambient avatar work is capped at 15 FPS while visible/focused; active semantic motion is capped at 30 FPS.
- CSS compositor animations pause at the same focus/visibility lifecycle boundary.
- Existing feature-host/runtime, BotMark motion, renderer and packaged tests pass.
- PR passes required CI, protected merge, post-main packaged E2E/Release, and canonical-main readback.

## Local verification before PR
- Hidden installed 1.0.2 baseline: `mahayana-app-host` approximately 21.6% CPU while renderer/GPU fell near zero.
- Process sample showed the host active in `feature_receive -> crossbeam_channel::Receiver::recv_timeout`.
- `node --test desktop/electron/host-process.test.cjs` — 5/5 pass for the original long-poll slice.
- Electron Feature Host bridge contract — pass with explicit `{ timeoutMs: 500 }` and Rust `receive_with_timeout` forwarding.
- Rust formatting/build validation is delegated to GitHub Actions because the repository's canonical native toolchain/build evidence is CI-hosted.

## 2026-08-24 renderer/GPU continuation

A second target-Mac measurement with packaged `1.0.798` while ChatGPT was foreground and Fabushi merely sat behind it showed the remaining dominant drain: Fabushi GPU process about `60.9% CPU` and renderer about `22.5% CPU`, while the local ChatGPT benchmark was near-idle (main about `0.2%`, GPU service about `1.3%` in the sampled process view).

Root cause: the shared BotMark engine kept its global `requestAnimationFrame` clock alive whenever marks were intersection-visible, even when the Fabushi document had lost focus; CSS aura/breathe/orbit animations also continued.

## 2026-09-07 closure continuation

The remaining renderer/GPU slice is now implemented on `fix/desktop-energy-ghost-white-release`:

- `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx`
  - hard-stops RAF when `document.visibilityState !== "visible"` or `document.hasFocus() === false`;
  - resumes immediately on `visibilitychange`, `focus`, and `blur` lifecycle reconciliation;
  - emits `html[data-fabushi-motion-paused]` so compositor CSS follows the same lifecycle;
  - caps low-energy states (`idle`, `sleeping`, `drowsy`, `bored`, `powering-down`) to 15 FPS and other active states to 30 FPS;
  - retains `prefers-reduced-motion`, semantic state profiles and imperative actions.
- `desktop/src/ios-white-desktop-theme.css`
  - pauses all CSS animation play-state while the document motion marker is paused.
- `.github/scripts/assert-bot-mark-motion.py`
  - fail-closed checks now require the hard background pause, 15/30 FPS caps and paused CSS lifecycle.
- The existing 500 ms Feature Host long poll remains unchanged and guarded; the continuation does not regress the host idle-wakeup fix.

Implementation commit lineage begins at `6e91c33a0ff8bf170570706dcc4c217dd626406b`; updated motion guard commit is `3f41b7885c55d3e2addf3d67a89d317754af427a`.

## Remaining authoritative gates

- Exact PR-head CI and renderer/native tests.
- Protected-main merge and canonical readback.
- Exact-main packaged desktop release/E2E.
- Post-release target-Mac idle/background CPU/energy remeasurement; sustained double-digit renderer/GPU/host CPU is a release blocker and must reopen/fail this task.

MSR-106 must remain `in-progress` until those gates and the packaged idle remeasurement are recorded.
