# MSR-101 — Upstream capability inventory

- **Task ID:** MSR-101
- **Status:** in-progress
- **Started:** 2026-08-22T15:19:00+08:00
- **Updated:** 2026-08-22T15:25:00+08:00
- **Completed:** null

## Objective
Pin current reviewed Codex and Grok Build revisions and create an auditable capability/provenance/gap inventory that drives implementation instead of copying either product wholesale.

## Source requirements
MSR-R01, MSR-R02, MSR-R03, MSR-R05, MSR-R06; upstream `openai/codex` and `xai-org/grok-build`; merged PR #1971.

## In scope
- reviewed upstream revisions;
- capability groups and new upstream deltas;
- Mahayana implementation/adapter/gap classification;
- provenance boundaries and execution order.

## Out of scope
Claiming runtime parity without tests or cross-surface evidence.

## Dependencies
MSR-001 — passed.

## Acceptance criteria
1. `SOURCES.lock` pins full current reviewed commit IDs for both upstreams.
2. Every required Codex/Grok Build capability family in project requirements is classified as native, adapter, partial, or gap.
3. New Codex `343074d` runtime-MCP-status and unfinished-turn-suspension deltas are captured.
4. Grok Build `19d42e35` goal/oracle/permission/loop/workflow deltas are captured.
5. CI/source-boundary checks pass, change merges through protected main, and the matrix is re-read from main.

## Verification
GitHub upstream commit audit; `docs/08-upstream-capability-matrix.md`; `SOURCES.lock`; required GitHub Actions; post-merge main verification.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Commit: pending final head
PR: pending

## Implementation summary
Updated upstream pins and added a capability/provenance/gap matrix that distinguishes already-native primitives from adapter dependencies and unresolved semantic/cross-surface acceptance gaps.

## Evidence
To be indexed under `evidence/MSR-101/` after CI/merge.

## Blockers / risks
Upstream projects continue to evolve; reviewed commits are reproducible audit inputs, not automatic vendoring targets.

## Next action
Finish CI/merge evidence, then keep the matrix current while MSR-103/201/202/301/302/401 close the identified gaps.
