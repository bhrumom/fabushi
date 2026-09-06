# 60 — 2026-09-05 M6 protected-main-safe parent-stack status

Current state: `ARCHITECTURE-MERGE-BLOCKED / MAINSAFE-RECOVERY-PLANNED / EXECUTION-NOT-STARTED`

## Verified current facts
- canonical main remains `688465e94647d4c866f6b1d7b4884145b2f4a9da` at architecture planning start.
- #2323 remains open/unmerged at `1c314ef514f71e5a1320ddea0803078923a4858c`, base `9e88a2e...`.
- parent delta is 12 commits; child delta is 22; full main-to-child head is 34.
- no independent bottom-of-stack PR targets main for `codex/tfi-m6-repair`.
- #2334 remains the authoritative test-release `MERGE-BLOCKED` record and is cited rather than copied/overwritten.

## Allowed next stage
Only `TFI-M6-MAINSAFE-001-RUST-CANONICAL` may be handed to a fresh execution-group session after this architecture handoff is complete. Tasks 002/003, code review, merge, canonical E2E, test release and formal release are not authorized now.

## Closure blockers
Architecture completion requires records-only PR/head readback plus #2323 and #2334 architecture handoff comments. Product closure remains blocked until the three main-safe layers pass their own gates.