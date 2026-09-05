# M3-DESKTOP-003 — Startup / first-message critical-path diagnostics

- Project: `FAB-P0001 / TFI`
- Task ID: `M3-DESKTOP-003`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `0`
- Risk: medium; diagnostic-only production instrumentation + packaged E2E

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
