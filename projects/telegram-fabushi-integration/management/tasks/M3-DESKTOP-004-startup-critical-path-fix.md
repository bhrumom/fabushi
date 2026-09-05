# M3-DESKTOP-004 — Fix measured desktop startup critical path

- Project: `FAB-P0001 / TFI`
- Task ID: `M3-DESKTOP-004`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED / BLOCKED on M3-DESKTOP-003`
- Wave: `1`
- Risk: high; startup/data-visibility regression

## Single objective

Remove only the measured P0-P9 critical-path bottleneck while preserving projection-first local startup and bounded background reconciliation.

## Dependency

`M3-DESKTOP-003` must identify the bottleneck and show it is fixable inside this exact allowlist. Otherwise this task fails closed back to architecture.

## Exact implementation allowlist

- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `desktop/e2e/messenger.spec.ts`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-004/**`

Forbidden: Electron auth/Host files, backend account service, unrelated Messenger UX, workflows/version files unless architecture is revised first.

## Acceptance

1. Cached returning-user packaged first interaction `<1000 ms`.
2. First visible selected-conversation message batch `<1000 ms`; initial bounded hydration `<2000 ms` on the seeded regression fixture.
3. Conversation metadata completeness is not limited by the heavy message payload bound; the projection can paint before Host/auth/network roundtrips.
4. P9/background account reconcile never gates P2/P7.
5. Offline/slow-host/restart cases still render safe cached state and converge without duplicates or data loss.
6. The exact P0-P9 trace shows the repaired phase and no new phase regression beyond agreed thresholds.

## CI / E2E evidence

Required PR-head tests plus packaged Electron cold/returning/offline/slow-host journeys. Evidence bundle: timing JSON, screenshots, video, trace, renderer/main logs, exact head SHA. After protected merge, exact-main packaged readback is required before `TESTED`.

## Failure-stop

If M3-DESKTOP-003 names a Host/auth/backend bottleneck outside the allowlist, do not implement a workaround here; return to architecture for a new atomic task.

## Rollback

Single-task revert must restore prior sync/hydration behavior without deleting the durable projection. Diagnostic markers from M3-DESKTOP-003 may remain if independently useful and approved.
