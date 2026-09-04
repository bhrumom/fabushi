# TFI-M3-P0-001 — desktop first-frame complete message hydration

- Project ID: `FAB-P0001`
- Task ID: `TFI-M3-P0-001`
- Status: `NOT_STARTED`
- Owner: Execution project group
- Dependencies: none
- Parallel: yes with M6 and MiniApp-card tasks.
- Source: existing `M3-DESKTOP-002`, `source/2026-08-24-startup-performance-release-gate.md`, current main.

## Objective

Eliminate the observed ~1 minute delay before message content becomes complete while preserving the existing local-first `<1000 ms` returning-user gate.

## Primary modules to inspect first

`desktop/src/messaging-shell-v2.tsx`; `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`; Host `conversation.open/opened` contract/producer; `desktop/e2e/messenger.spec.ts`; existing client-persistence projection path.

## Implementation contract

1. Trace actual current-main first frame before editing; measure projection read -> normalization -> render -> `conversation.open` -> `conversation.opened` reconciliation.
2. Cached message entries must be normalized into the same `DisplayMessage` semantics used by live Host events; no placeholder body that waits for open/opened.
3. Paint valid local projection before Host/auth/network round trips. Issue open/sync asynchronously.
4. Reconcile late canonical events monotonically; an empty/intermediate live response cannot blank complete cache unless canonical deletion is explicit.
5. Remove/avoid minute-scale timeout/poll dependency from content completeness, but do not create a second canonical store.

## Acceptance

- Focused renderer/transport contract tests prove first render contains seeded complete bodies and reconciliation does not regress them.
- Packaged full-close/relaunch journey with production persistence records `<1000 ms` conversation-list first interactive and separately records message-content-complete timing.
- Full video visibly shows complete messages on first usable frame; step screenshots, trace, report and logs retained even on failures.
- transient Host/auth/network failure keeps valid cached Messenger; explicit signed-out still routes correctly.
- GitHub Actions/protected-main/exact-main packaged gates only; no local build/E2E.