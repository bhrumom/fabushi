# TFI-M6-P0-003 — Community admission/authz and negative contracts

- Project ID: `FAB-P0001`
- Task ID: `TFI-M6-P0-003`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependency: `TFI-M6-P0-002 REVIEW-PASS`
- Parallel: may run with P0-004 only if files are split and merge conflict risk is agreed by architecture owner.

## Objective

Close public/private/invite/join_request admission for Group/Channel and prove deny paths.

## Required contract

- Public join, private direct subscribe, invite-token join and join-request approval are distinct typed paths.
- `SubscribeChannel` cannot bypass private/invite/join-request policy.
- `RequestCommunityJoin` requires an existing appropriate Community and cannot call `CommunityState::new()` to capture an unowned conversation ID.
- Invite token scope, expiry, revoke and replay/use rules are enforced.
- banned/non-member/member/admin/owner actors receive only allowed operations.
- server-side policy is authoritative; client conversation/participant fields cannot grant admission.

## Tests

Positive and negative matrix for public/private channel/group, malformed/expired/revoked invite, duplicate request, already-member, banned actor, unauthorized approval, owner/admin permission edges. Include regressions for every previously rejected strict-review path.

No protocol version negotiation or journal redesign in this task.