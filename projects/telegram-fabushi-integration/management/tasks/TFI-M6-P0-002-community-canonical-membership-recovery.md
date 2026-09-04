# TFI-M6-P0-002 — Community canonical membership and recovery projection

- Project ID: `FAB-P0001`
- Task ID: `TFI-M6-P0-002`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependency: `TFI-M6-P0-001 REVIEW-PASS`
- Parallel: no with overlapping M6 engine/service task.

## Objective

For Group/Channel backed by Community, make `CommunityState.members` the sole membership authority across live mutation, persisted restore, snapshot, event projection and Conversation participants.

## Modules

`community.rs`, `conversation.rs`, `engine.rs`, `service.rs`, state store/recovery helpers reached by these modules, M6 contract tests.

## Required changes

- Recovery reconstructs Conversation participants from Community rather than trusting stale persisted/raw participant vectors.
- Community member add/remove/approve/ban/leave/admin-role changes deterministically rebuild/project participants.
- Raw `SetConversationParticipant` / remove cannot mutate Community-backed membership.
- Owner/admin downgrade invariants are explicit; Channel and Group both covered.
- Self-leave and owner-leave behavior are typed, tested and cannot orphan authority.
- Legacy fixtures are migrated/read compatibly or fail with an explicit repair path; no silent privilege grant.

## Acceptance

Unit/contract fixtures cover restart/reload plus admin downgrade, ban, leave, approval, Group, Channel and legacy state. The same canonical member set is observed before and after restart. GitHub Actions only for build/tests; record all evidence and PR metadata.