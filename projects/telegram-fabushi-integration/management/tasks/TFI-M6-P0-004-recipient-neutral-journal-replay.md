# TFI-M6-P0-004 — recipient-neutral journal and privileged replay

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-004`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependency:** `TFI-M6-P0-002 REVIEW-PASS`.
- **Parallel condition:** may run with M6-003 only with disjoint ownership; any shared `service.rs`/`engine.rs` change serializes.

## Objective
Persist historical messaging/community facts once in recipient-neutral form and apply member/admin visibility only when reading/projecting.

## Exact implementation scope
- `native/mahayana-messaging/src/store.rs`: `JournalEntry`, `MessagingStateStore`, memory/sqlite journal persistence and schema compatibility. Current audited `JournalEntry` includes persisted `audience`, so migration/compatibility must be explicit.
- `native/mahayana-messaging/src/service.rs`: `journal_entries`, `sync_response`, `project_journal_envelope_for_actor`, audit-page authorization and replay projection.
- `native/mahayana-messaging/src/engine.rs` / `community.rs`: canonical Community facts needed for replay/projection only.
- `native/mahayana-messaging/src/protocol.rs`: only for an explicit versioned journal/read envelope if required by accepted design.
- focused store/service replay fixtures/tests.

## Implementation steps
1. After M6-002 acceptance, map every persisted event and distinguish durable fact from recipient-specific projection.
2. Remove actor-triggered redaction from durable history; if `audience` remains for delivery routing, prove it cannot permanently erase facts needed by a later-authorized reader, or migrate to a recipient-neutral representation.
3. Persist canonical Community state once; derive participants on read/recovery.
4. Apply current member/admin/owner visibility at read time; promotion can reveal permitted historical audit facts, downgrade/banned state cannot leak them.
5. Preserve cursor/order/idempotency and define schema migration for prior journal rows.
6. Add member->admin, admin->member, banned/new-device/restart, Group+Channel matrix.

## In scope
Journal schema/persistence/replay visibility and historical admin authorization.

## Out of scope
Admission policy, protocol v3 negotiation except minimal compatible schema need, UI redesign, local build/test.

## Acceptance by category
- **Unit:** journal serialization/migration, actor projection and current-role visibility units.
- **Contract:** member->admin can read permitted prior facts; admin->member/banned cannot read privileged fields; no historical fact required by policy is lost; cursor/order stable.
- **Integration:** SQLite/memory store persist -> restart -> sync as different authorized actors proves no leak/no loss.
- **E2E:** exact-main installable multi-user restart/replay journey demonstrates privileged audit visibility changes with current role and ordinary transcript remains intact.
- **Security:** privileged audit fields never leak to ordinary/banned actors; stale persisted recipient metadata cannot grant access.
- **Performance:** replay remains cursor-bounded by existing journal limits and avoids full-history per-recipient duplication; record any size/latency delta in Actions evidence.

## Required write-back and evidence
Record dependency acceptance, branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog here and in TFI P0 records. No planned=passed.

Post-main closure requires exact accepted main SHA, app version, platform, run/job, journey ID, timestamp, installable artifact, full video, step screenshots, trace, HTML/native report and logs; pass/fail always-equivalent upload; 90-day target or recorded lower maximum. Missing evidence blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
