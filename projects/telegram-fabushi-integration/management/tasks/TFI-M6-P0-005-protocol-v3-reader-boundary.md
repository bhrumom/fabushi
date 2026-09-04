# TFI-M6-P0-005 — protocol v2 reader boundary and v3 negotiation

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-005`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependencies:** `TFI-M6-P0-003 REVIEW-PASS` and `TFI-M6-P0-004 REVIEW-PASS`.
- **Parallel condition:** no concurrent protocol/gateway/request-bridge task may edit the same version boundary.

## Objective
Introduce the minimum compatible v3 negotiation needed for admission context, authoritative server time and request correlation without breaking existing v2 readers.

## Exact implementation scope
- `native/mahayana-messaging/src/protocol.rs`: currently `FABUSHI_MESSAGING_PROTOCOL_VERSION = 2`; versioned client/server envelopes, negotiation fields and fixture types.
- `native/mahayana-messaging/src/service.rs`: protocol validation/selected version, authoritative `server_time_ms`, request idempotency/correlation and actor-safe projection.
- `native/mahayana-messaging/src/gateway.rs`: connection/request negotiation boundary.
- `frontend/apps/web/src/lib/mahayana-host/contracts.ts`: desktop reader types for negotiated envelopes if required.
- `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`: request bridge/retry/idempotency reader boundary.
- existing v2 golden fixtures and focused protocol/gateway/transport tests.

## Implementation steps
1. Freeze fixture-backed v2 reader behavior before introducing v3.
2. Add explicit `supported_versions`/selected version at the connection/request boundary; reject unsupported future versions.
3. Ensure negotiated v2 emits only v2-compatible fields/events; v3 can add admission context, server time and correlation without contaminating v2 wire shape.
4. Use server time for expiry/permission decisions; client `sent_at_ms` remains diagnostic.
5. Make mutating request retry/reconnect idempotent by request ID where required; no double-apply.
6. Preserve legacy topic/thread fixture syntax and add v2/v3/clock-skew/replay matrix.

## In scope
v2 reader preservation, v3 negotiation, server-time authority, request correlation/bridge compatibility.

## Out of scope
New business features beyond fields needed by accepted M6 semantics; replacing transport stack; local build/test.

## Acceptance by category
- **Unit:** version selection, future-version rejection, request-ID replay and server-time expiry helpers.
- **Contract:** golden v2 fixtures decode/round-trip unchanged; negotiated v2 sees no v3-only fields; v3 positive fixtures and unsupported-version negatives pass.
- **Integration:** gateway -> service -> Electron transport reconnect/retry proves selected version and no duplicate mutation.
- **E2E:** exact-main installable desktop using supported current version opens/syncs Group/Channel; compatibility fixture/legacy client gate remains green.
- **Security:** client clock cannot extend invite/approval validity; version downgrade/future injection/replay cannot bypass authz or duplicate a mutation.
- **Performance:** negotiation adds bounded handshake/request overhead; record protocol/open timing and prove no retry loop or material startup regression.

## Required write-back and evidence
Record accepted dependency heads, branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog here and in TFI P0 records. Planned/pending is not passed.

Post-main closure requires exact main SHA/app version/platform/run+job/journey/timestamp/installable artifact/full video/step screenshots/trace/HTML-native report/logs; pass/fail always-equivalent upload; 90-day target or recorded lower maximum. Missing evidence blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
