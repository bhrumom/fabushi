# TFI-M6-P0-003 — Community admission/authz and negative contracts

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-003`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependency:** `TFI-M6-P0-002` must first have contract acceptance, independent code review `REVIEW-PASS`, protected canonical-main merge, all required CI green, and installable/packaged E2E plus Release evidence tied to the exact accepted canonical-main SHA. Until every condition is present, this task remains `BLOCKED`; any source reading/schema/test-vector preparation is contract-only and admission implementation cannot be submitted, accepted, or closed.
- **Parallel condition:** may run with TFI-M6-P0-004 only after the complete dependency gate is satisfied and architecture owner confirms disjoint file ownership; shared `service.rs`/`engine.rs` edits serialize.

## Objective
Close public/private/invite/join-request admission and authorization for Community-backed Group/Channel and prove both allow and deny paths.

## Verified current-state correction
At audited `codex/tfi-m6-repair@9e88a2e9...`, no-Community `RequestCommunityJoin` already returns `CommunityNotFound`. Treat this as a mandatory regression gate, **not** as an unresolved `CommunityState::new()` capture defect. Admission remains incomplete because subscribe/join mode policy and its negative matrix are not fully enforced.

## Exact implementation scope
- `native/mahayana-messaging/src/access.rs`: actor/session authorization helpers used by admission.
- `native/mahayana-messaging/src/community.rs`: admission mode, invite, join request, member/banned state.
- `native/mahayana-messaging/src/engine.rs`: subscribe/join/request/respond mutation semantics.
- `native/mahayana-messaging/src/service.rs`: `SubscribeChannel`, `RequestCommunityJoin`, invite/join response authorization and command projection.
- `native/mahayana-messaging/src/protocol.rs`: existing typed commands/errors only when required for explicit admission result.
- focused admission tests/fixtures under existing `native/mahayana-messaging/**`.

## Implementation steps
1. Re-read the exact accepted canonical-main M6-002 state and its package/Release lineage, then enumerate public/private/invite/join-request modes for both Group and Channel.
2. Enforce distinct typed paths; `SubscribeChannel` must not bypass private/invite/join-request policy.
3. Preserve `RequestCommunityJoin` missing-Community -> `CommunityNotFound` as regression.
4. Enforce invite scope, expiry, revoke, replay/use rules using server-authoritative time where available in current protocol; any v3-specific time contract is deferred to M6-005.
5. Enforce banned/member/admin/owner and unauthorized approval rules; client participant fields never grant admission.
6. Add full positive/negative matrix before handoff.

## In scope
Admission/authz semantics and tests for public/private/invite/join-request.

## Out of scope
Protocol negotiation/version framing, recipient-neutral journal redesign, desktop renderer, local build/test.

## Acceptance by category
- **Dependency gate:** M6-002 itself is fully delivered: accepted contract + independent `REVIEW-PASS` + protected canonical merge + required CI + exact-accepted-main installable/packaged E2E and Release evidence. Missing any part blocks acceptance.
- **Unit:** mode transition, invite validate/expiry/revoke/replay, duplicate request, already-member and banned actor units.
- **Contract:** public/private/invite/join-request positive+negative matrix for Group and Channel; missing Community remains `CommunityNotFound`; unauthorized approval/subscribe fails closed.
- **Integration:** authenticated service -> engine tests prove actor/session and policy state are authoritative, not client-provided participant fields.
- **E2E:** exact-main installable Group/Channel join journeys include allowed public join and visible denial for private/no-invite, expired/revoked invite and unauthorized approval.
- **Security:** ban, privilege, invite replay, cross-community token, forged participant/owner and policy-bypass negatives all fail closed.
- **Performance:** admission checks are local/bounded against canonical state and do not introduce repeated polling; existing messaging latency smoke must not regress.

## Required write-back and evidence
Record M6-002 exact contract/review/protected-main/required-CI/package-E2E/Release lineage and then this task's branch/commit/PR/review head+verdict/CI workflow-run-job/check/evidence/status/changelog in this file and TFI P0 management/evidence. Planned is not passed.

This task's own post-main closure requires exact-main installable package identity plus app version/platform/run+job/journey/timestamp/full video/step screenshots/trace/HTML-native report/logs. Upload pass+fail on always-equivalent path; target 90 days or record platform maximum. Missing prerequisite or own evidence blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
