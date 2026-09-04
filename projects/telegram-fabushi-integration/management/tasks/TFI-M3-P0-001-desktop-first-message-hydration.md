# TFI-M3-P0-001 — desktop first-frame complete message hydration

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M3-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `NOT_STARTED`
- **Owner:** Execution project group
- **Current dependencies:** none
- **Parallel condition:** may run with M6 and MiniApp-card tasks only when no listed source file overlaps.

## Objective
Eliminate the observed ~1 minute delay before message bodies become complete while preserving the existing local-first returning-user gate and a single canonical messaging store.

## Exact implementation scope
- `desktop/src/messaging-shell-v2.tsx`: cached/live events -> `DisplayMessage`, active-conversation open/reconcile.
- `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`: `messenger-projection.v1`/conversation journal hydration and live merge.
- `frontend/apps/web/src/lib/mahayana-host/contracts.ts`: only if existing `conversation.open/opened` typing cannot express the verified boundary.
- `frontend/apps/web/src/lib/mahayana-host/coordinator.ts`: request/open boundary only if tracing proves it participates in the delay.
- `desktop/e2e/messenger.spec.ts` and existing startup-performance journey/fixtures: task-specific regression/E2E.
No other persistence store may be introduced.

## Implementation steps
1. On the exact implementation head, instrument/trace projection read -> normalization -> first render -> `conversation.open` -> `conversation.opened`; record root cause before changing semantics.
2. Normalize valid cached message records into the same `DisplayMessage` shape as live Host messages; complete cached body must not wait for `conversation.opened`.
3. Paint valid local projection before auth/network/Host round trips; issue open/sync asynchronously.
4. Reconcile late canonical events monotonically: empty/intermediate responses cannot blank a complete cache unless an explicit canonical deletion exists.
5. Remove any minute-scale poll/timeout dependency from message-content completeness; keep one canonical persistence authority.
6. Add focused contracts and exact-main packaged full-close/relaunch evidence.

## In scope
Returning-user local projection, message-body completeness, open/opened reconciliation, relevant renderer/transport tests and packaged startup evidence.

## Out of scope
Messaging protocol redesign, new storage engine, M6 Community semantics, MiniApp/Bot behavior, local build/test.

## Acceptance by category
- **Unit:** normalization/merge helpers preserve complete cached bodies, deletion semantics and deterministic ordering.
- **Contract:** `conversation.open/opened` and cached projection produce equivalent `DisplayMessage` semantics; empty late payload cannot erase a complete cached message.
- **Integration:** Electron transport + renderer seeded persistence path proves first usable render from cache while Host open/sync runs asynchronously.
- **E2E:** installable exact-main Electron package full-close/relaunch journey records conversation-list first interactive `<1000 ms` and separately records message-content-complete timing; video visibly proves complete bodies on first usable frame.
- **Security:** signed-out/invalid-session behavior remains explicit; cached data is not exposed across account identity and transient auth/network failure does not fabricate authorization.
- **Performance:** startup JSON records both list-interactive and content-complete timing; no minute-scale timeout/poll is on the critical content path and existing startup threshold does not regress.

## Required write-back and evidence
Before handoff, update **this file** with actual branch, commit, PR, reviewed head/verdict, GitHub Actions workflow/run/job/check results, evidence paths, status and changelog entry; also update TFI P0 WBS/acceptance/dependency/status/change/evidence records. Planned/pending values remain pending; execution cannot self-award `REVIEW-PASS`.

Application closure additionally requires protected merge and an **installable/package** built from the exact accepted canonical-main SHA. Record exact main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, package artifact, complete video, step-labelled screenshots, trace, HTML/test report and logs. Upload pass **and** fail evidence on an `always()`-equivalent path; target 90-day retention, or the platform maximum with the lower limit recorded. Missing any required artifact/identity field blocks pass. Source-only green tests do not satisfy closure. Release, if required by delivery, must trace to the same SHA/package lineage.

## Execution fields
- Branch: `pending`
- Commit: `pending`
- PR: `pending`
- CI: `pending`
- Evidence: `pending`
- Code-review status: `pending`
- Canonical-main/package/release: `pending`
