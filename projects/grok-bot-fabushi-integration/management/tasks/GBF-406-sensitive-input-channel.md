# GBF-406 — Sensitive-input one-time channel

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependency: `GBF-401`

## Objective

Create a separate one-time sensitive-input grant that never places secrets in normal model/tool payloads, logs or replayable action history.

## Acceptance

- Sensitive values are referenced by opaque request/grant IDs, not normal `ComputerAction.text`.
- Approve/deny/expire/revoke/replay are enforced.
- A successful consume is single-use and zeroizes/removes stored plaintext promptly.
- Audit records metadata/outcome only, never the secret value.
- Security tests cover expiry, replay, wrong target and denial.

## Evidence

Target: `evidence/GBF-406/` plus CI links and merged commit.
