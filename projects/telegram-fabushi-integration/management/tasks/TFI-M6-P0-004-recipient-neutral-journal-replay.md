# TFI-M6-P0-004 — recipient-neutral journal and privileged replay

- Project ID: `FAB-P0001`
- Task ID: `TFI-M6-P0-004`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependency: `TFI-M6-P0-002 REVIEW-PASS`

## Objective

Persist historical messaging/community facts once, independent of the actor who happened to trigger persistence, and apply recipient/admin visibility only when reading/projecting.

## Contract

- Durable journal entries cannot contain actor-specific redaction that makes replay incomplete for another authorized actor.
- Community canonical state is persisted once; Conversation participant projection is rebuilt from it.
- Admin audit history is returned only to current authorized admins/owner at read time.
- Ordinary members cannot retrieve privileged audit fields; later admin promotion can read historical facts that policy permits without missing data.
- replay/restart is idempotent and preserves cursor/order.

## Tests

Historical replay as member -> admin, admin -> downgraded member, banned actor, new device, restart, and mixed Group/Channel. Assert no privileged leak and no historical loss. GitHub Actions is the heavy verification source.