# M3-DESKTOP-003 — Startup / first-message critical-path diagnostics

- Project: `FAB-P0001 / TFI`
- Task ID: `M3-DESKTOP-003`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `TESTING`
- Execution state: `READY_FOR_TEST`
- Wave: `0`
- Risk: medium; diagnostic-only production instrumentation + packaged E2E
- Architecture base: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- Execution branch: `feat/tfi-m3-desktop-003-startup-diagnostics`

## Single objective

Reproduce the reported ~1 minute desktop message hydration delay and produce one monotonic P0-P9 trace that identifies the actual critical-path phase. Do not change startup semantics in this task.

## Inputs

- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-002-local-first-settings.md`
- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/e2e/messenger.spec.ts`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/engine.rs`

## Exact implementation allowlist

- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/e2e/messenger.spec.ts`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/**`
- this task record/status evidence only

Forbidden: auth semantics, Host lifecycle semantics, messaging protocol/schema, workflow/release/version files, unrelated UI.

## Required outputs

A timestamped trace containing P0 renderer navigation; P1 projection read; P2 shell first paint/interactive; P3 auth restore; P4 Host ready observation; P5 first snapshot request/batch; P6 conversation metadata complete; P7 first visible message/initial hydration complete; P8 event stream live/backlog; P9 background reconcile. Include counts/bytes/cache-hit, relevant IPC/network durations and renderer long-task markers.

## Acceptance

1. Packaged Electron returning-user case has a seeded durable projection and enough history to expose hydration behavior; no test-only bypass may replace the product path.
2. `startup-performance.json` is extended or accompanied by `startup-critical-path.json` with all P0-P9 markers or an explicit `unobservable` reason per marker.
3. At least one run reproduces the user-visible delayed-completion symptom or proves it does not reproduce on the tested exact head; either outcome includes trace/video/screenshots.
4. The task states one measured bottleneck classification and the exact files/functions implicated. It must not claim a root cause from timing constants alone.
5. No startup behavior change is included; diff is diagnostic/test-only within the allowlist.

## CI / E2E evidence

PR-head: renderer TypeScript + existing messaging/unit gates + packaged Electron messenger E2E. Preserve JSON timing artifact, Playwright trace, video, screenshots, app/main logs and exact head SHA. Heavy verification runs only in GitHub Actions.

## Failure-stop

If the symptom requires changing code outside the allowlist to make it observable, stop and return to architecture with the missing seam; do not widen scope in-session.

## Rollback

Revert the diagnostic markers/test extension; this task must leave no canonical state/schema migration.

## Execution implementation — 2026-09-05

### Scope and behavior boundary

Implementation is diagnostic/test-only and remains inside the frozen allowlist. It does **not** change message commands, sync command parameters, transport return values, error propagation, event ordering, startup routing, auth semantics, Host lifecycle semantics, protocol/schema, MiniApp, Mahayana CLI, GBF device control, workflow, release, or version behavior.

The transport observations wrap the already-used transport instance and return the original results or rethrow the original failure. The existing self-hosted `sync` command remains exactly `{ type: 'sync', cursor, limit }`.

### P0-P9 instrumentation

- P0/P1/P2: renderer navigation/time origin, projection `localStorage` hit/bytes/read duration, paint/double-rAF first-frame observation.
- P3/P4: existing `authStatus()` and `initialize()` completion/rejection durations.
- P5/P6: initial `sync` request plus first `syncBatch` counts/bytes/cursor and conversation/actor metadata completion.
- P7: first message entering the existing renderer formatting/render path, recorded on the next animation frame.
- P8: first subscribed runtime event and first sync backlog counts/bytes.
- P9: second/background reconcile `sync` request and completion duration.
- Renderer Long Task markers use the browser Performance Observer where supported; unsupported observation is explicitly recorded.

### Packaged returning-user E2E extension

The existing startup performance test now seeds `32` real self-hosted text messages through the Host command path, exceeding the current initial snapshot message limit `20`. It waits for both renderer and native durable projection persistence, fully relaunches Electron, requires the projected conversation and newest message to be visible, waits for P0-P9, then writes/attaches `startup-critical-path.json` while retaining `startup-performance.json`. The critical-path artifact contains `rootCauseClaim: null` until a real packaged trace is reviewed.

### Modified files

- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/e2e/messenger.spec.ts`
- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-003-startup-first-message-diagnostics.md`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/README.md`

`desktop/src/messaging-shell-v2.tsx` was inspected but did not need modification. No out-of-allowlist file is modified.

### Risk

- Instrumentation adds timestamp/size-accounting overhead and can perturb diagnostic timing slightly.
- Serializing a large `syncBatch` only to estimate bytes can add renderer work; this is diagnostic-only and rollback is a clean revert.
- Long Task entries depend on packaged Chromium support; the artifact records unsupported status/reason rather than inferring a value.
- P7 observation is not itself a bottleneck or root-cause claim.

### Rollback

Revert the M3-DESKTOP-003 execution PR/commits. No schema/state migration or release control change is present, so rollback is removal of the diagnostic wrappers and E2E evidence extension only.

### CI / E2E acceptance pending

No local build, native test, E2E, or package operation was run. GitHub Actions on the exact PR head must provide:

1. renderer TypeScript/typecheck and existing desktop quality gates;
2. existing messaging/unit/product gates;
3. packaged Electron Messenger E2E;
4. `startup-performance.json` and `startup-critical-path.json` from the exact head;
5. P0-P9 presence, or an explicit unobservable reason where runtime support is absent;
6. Playwright trace, video, screenshot, app/main logs and exact head SHA;
7. a factual result stating whether the delayed-completion symptom reproduced;
8. only then, a measured bottleneck classification with exact implicated file/function. No timing constant alone may be promoted to root cause.

Detailed execution evidence: `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/README.md`.
