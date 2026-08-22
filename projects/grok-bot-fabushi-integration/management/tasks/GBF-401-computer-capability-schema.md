# GBF-401 — Computer-control capability schema

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependencies: `GBF-204`, `GBF-305`

## Objective

Define the single versioned, target-bound capability contract for observe/input/window/browser/sensitive-input computer control. Grants must be scoped, expirable, revocable, replay-resistant and auditable; denial must have no side effects.

## Acceptance

- Versioned capability/grant schema is serialized by `mahayana-host-protocol`.
- Every high-risk operation maps to an explicit scope and target identity.
- Grant expiry/revocation/nonce replay are enforced before execution.
- Local UI, AI and remote mobile share the same policy boundary.
- Contract/security tests cover allow, deny, expire, revoke and replay.

## Evidence

Target: `evidence/GBF-401/` plus CI links and merged commit.
