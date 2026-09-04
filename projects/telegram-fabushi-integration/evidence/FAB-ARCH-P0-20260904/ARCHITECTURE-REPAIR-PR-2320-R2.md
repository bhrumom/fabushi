# ARCHITECTURE REPAIR — PR #2320 R2 — TFI

- Project: `FAB-P0001 / TFI`
- Program: `FAB-ARCH-P0-20260904`
- Branch: `arch/p0-recovery-20260904`
- Base: canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- R2 reviewed/rejected head: `a5ce2e522cf124910c6627c72a646513b90960fa`
- R2 review: `REVIEW-REJECTED`, GitHub COMMENT review id `5113492839`
- Review record PR: `#2321@a9e965a9a4dfd47baeb72742a29e6ef3eda402c2` — historical record only; not modified by this repair
- R2 repair content commit/head before evidence write-back: `a116f63b9d7d1f89422069605caebbb8475f0567`
- Governance PR: `#2320`, open/unmerged at repair time
- Owner: Architecture project group; next owner: independent code-review group

## R2 blockers repaired
1. Task-local hard dependency gates now require for every actual prerequisite: contract acceptance + independent `REVIEW-PASS` + protected canonical-main merge + required CI + installable/packaged E2E and Release evidence bound to that prerequisite's exact accepted canonical-main SHA. Review-only or shared release prose is insufficient.
2. TFI-M7 semantic/App/MiniApp -> Computer Use fallback now requires genuine semantic unavailability, same-account pairing, control enabled, current/non-revoked target/session/client/generation, granted unexpired approval, explicit MiniApp/install permission and end-to-end audit/correlation. Deny/expire/stale/revoke/install-disallow/available-but-denied/missing-correlation all fail closed.

## TFI changed files in repair content commit
- `management/tasks/TFI-M6-P0-002-community-canonical-membership-recovery.md`
- `management/tasks/TFI-M6-P0-003-community-admission-authz-negative-contracts.md`
- `management/tasks/TFI-M6-P0-004-recipient-neutral-journal-replay.md`
- `management/tasks/TFI-M6-P0-005-protocol-v3-reader-boundary.md`
- `management/tasks/TFI-M8-P0-002-install-miniapp-bot-projection.md`
- `management/tasks/TFI-M7-P0-001-group-bot-messaging-contract.md`
- `management/09-2026-09-04-P0-WBS.md`
- `management/10-2026-09-04-P0-里程碑.md`
- `management/11-2026-09-04-P0-验收追踪.md`
- `management/12-2026-09-04-P0-风险与依赖.md`
- `management/13-2026-09-04-P0-变更日志.md`

## Dependency truth / status
- `MSR-201`, `MSR-202`: still `in-progress`.
- `GBF-409`, `GBF-411`: still `IN_PROGRESS`.
- Therefore TFI-M8-P0-002 and TFI-M7-P0-001 remain `BLOCKED`; M6 chained tasks remain BLOCKED until their task-local FULL-CLOSE predecessors finish.
- Allowed early work is explicitly `contract-only`; blocked implementation cannot be submitted/accepted/closed.

## Verification and claims
- Scope is governance-only under `projects/**`.
- No application source, root `AGENTS.md`, CI or workflow was modified.
- No local build/test was run.
- This repair does **not** claim protected merge, required CI, packaged E2E or Release success.
- Historical R2 `REVIEW-REJECTED` is preserved and not overwritten.

## Handoff
Execution remains unauthorized. The independent code-review group must review the **latest live PR #2320 head after evidence write-back**, not merely `a116f63...`, inspect the real diff and issue a new `REVIEW-PASS` or `REVIEW-REJECTED`. Only a new independent `REVIEW-PASS` may authorize the execution group; later task execution still obeys every prerequisite FULL-CLOSE gate.