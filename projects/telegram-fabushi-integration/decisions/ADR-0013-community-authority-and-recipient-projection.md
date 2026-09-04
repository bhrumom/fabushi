# ADR-0013 — Community authority and recipient projection

- **Project**: `FAB-P0001` / `TFI`
- **Status**: Proposed
- **Date**: 2026-09-04

## Decision

For M6, `CommunityState.members` is the policy authority for Group/Channel admission,
while `Conversation.participants` is its server-maintained active-participant projection.
Join, approval, moderation, and participant changes must converge both views in one Rust
state transition. `CommunityState.topics` is the write authority; `Conversation.topics`
is a compatibility projection regenerated from it.

The durable journal stores recipient-neutral community mutations with audience metadata.
Direct responses and replay responses are projected for the receiving actor at read time.
Actor-specific unread counts, invite credentials, pending requests, and admin history are
never written as the shared projection.

Protocol rollout must preserve the existing v2 reader boundary while a negotiated v3
client receives M6-only events. Unsupported versions fail with an explicit supported
range; no client silently treats a new enum variant as an old event.

## Consequences

- Private channels require public admission policy or a validated invite; missing
  Community state is never created by an outsider request.
- Legacy non-`topic:<id>` thread roots remain ordinary message threads.
- Snapshot migration must be deterministic and idempotent when reconciling the two
  compatibility projections.
- Electron must merge recipient-scoped Community deltas without erasing privileged local
  state because another actor generated a public mutation.

## Scope boundary

This ADR does not introduce a second messaging runtime, Telegram protocol dependency,
Mini App runtime, or Mahayana agent implementation. Those remain in their existing
project/task tracks.
