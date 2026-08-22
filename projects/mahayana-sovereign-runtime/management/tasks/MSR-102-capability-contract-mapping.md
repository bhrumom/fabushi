# MSR-102 — Capability-to-contract mapping

- **Task ID:** MSR-102
- **Status:** in-progress
- **Started:** 2026-08-22T15:21:00+08:00
- **Updated:** 2026-08-22T15:25:00+08:00
- **Completed:** null

## Objective
Map every required upstream capability family to a Mahayana-owned contract/implementation or an explicit adapter/gap so no feature is silently lost during convergence.

## Source requirements
MSR-R01 through MSR-R08; `docs/08-upstream-capability-matrix.md`.

## In scope
Kernel/session/workspace/tool/memory/workflow/extension/model/policy domains plus Fabushi-specific cross-platform/conversation/tool-plane differentiation.

## Out of scope
Marking `partial` rows as passed before objective conformance/E2E evidence exists.

## Dependencies
MSR-101 inventory.

## Acceptance criteria
1. Every required Codex and Grok Build capability family is classified.
2. Each non-native row names the concrete next MSR task.
3. Fabushi/Mahayana differentiators are explicitly protected from upstream architecture leakage.
4. Traceability matrix references the mapping and remains evidence-gated.
5. Protected-main merge and post-merge verification complete.

## Verification
Capability matrix audit against project requirements and current Mahayana source; GitHub CI and protected merge.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Commit: pending final head
PR: pending

## Implementation summary
The first complete mapping is in `docs/08-upstream-capability-matrix.md`; it identifies native primitives already present in kernel/workspace/orchestrator/MCP and routes remaining gaps to MSR-103/201/202/301/302/401/501/601.

## Evidence
To be indexed under `evidence/MSR-102/` after CI/merge.

## Blockers / risks
Some native primitives are not yet wired into production execution paths; those rows intentionally remain `partial` rather than being overstated.

## Next action
Use the matrix as the implementation backlog, starting with MSR-103 product auth/secrets isolation.
