# FPG-005 — Parallel PR execution with PR-to-main completion gate

- Project ID: `FAB-P0002`
- Project Key: `FPG`
- Task ID: `FPG-005`
- Original source: `source/2026-08-24-FPG-005-pr-main-serialization.md`
- Clarification source: `source/2026-08-24-FPG-005-parallel-pr-clarification.md`
- Status: `in-progress`
- Started: `2026-08-24`
- Updated: `2026-08-24`
- Completed: pending

## Objective

Allow independent Fabushi repository tasks/PRs to proceed in parallel, including while another PR is waiting on CI/review/merge queue, while enforcing a strict **per-task completion gate**: before any individual task is marked or reported complete, that task's own PR must pass required gates, merge to canonical `main`, and be verified on `main`.

## Requirement evolution

The initial FPG-005 interpretation made task/PR execution strictly serial. The user then explicitly clarified that waiting on one PR must not block work on other tasks. The latest requirement therefore supersedes only the strict-serialization interpretation while preserving the original merge-before-task-completion requirement.

## In scope

- root `AGENTS.md` parallel-work + per-task PR-to-main completion gate;
- durable original requirement plus later clarification source;
- WBS and acceptance traceability;
- status/changelog evidence;
- protected PR merge and canonical-main readback for this correction.

## Out of scope

- changing GitHub branch protection settings;
- limiting the number of simultaneously active PRs;
- implementing a new CI bot for concurrency control;
- redesigning project scheduling/priority policy.

## Acceptance criteria

1. `AGENTS.md` explicitly allows creating, switching to, implementing, and advancing independent tasks/PRs while another PR is waiting on CI/review/branch protection/merge queue.
2. Parallel work does not allow a pending PR to be abandoned; every task retains its own durable status, PR/CI evidence, blockers, and next action.
3. Before an individual task is marked `passed` / `completed` or reported finished, that task's own PR must be actively driven through required review/CI/protected merge, merged to canonical `main`, and verified by canonical-main readback.
4. If a task's PR cannot yet merge, that task remains `in-progress`, `blocked`, or `failed`, but other independent tasks may continue in parallel.
5. This FPG-005 correction itself must pass required checks, protected merge, and canonical-main verification before FPG-005 is marked passed.

## Verification

- GitHub PR diff review;
- required GitHub Actions checks;
- protected merge/merge-queue result;
- post-merge fetch of canonical `main` `AGENTS.md` and project records.

## Branch / commit / PR evidence

### Initial interpretation
- Branch: `governance/fpg-005-pr-main-serialization`
- Initial source commit: `6209e77a50ebfc889a2234ec3fb53df3169e7d6b`
- Initial AGENTS commit: `de50a82a734d2fb49ec0538c46e8b409c29d41c6`
- PR: `#2076`
- PR result: merged to `main`
- Merge commit: `3ac9f841b4d5d1b2e9972c6ddbb661199260910b`
- Finding: implementation was too strict because it prohibited parallel work while a PR waited.

### Corrected interpretation
- Branch: `governance/fpg-005-parallel-closure-gate`
- Corrected AGENTS commit: `20b8636e613c3f6918a99a8b2175e0c367a36130`
- Clarification source commit: `6be18160f1c69402214bbef17a274ceca6507220`
- Correction PR: pending

## Implementation summary

Root `AGENTS.md` now defines parallelism as normal: multiple independent tasks/PRs may advance concurrently, especially during CI/review/merge waits. The strict rule is moved to the completion boundary: each task must return to its own PR, resolve blockers where possible, merge through protected `main`, and verify canonical `main` before that task can be declared finished.

## Evidence

- Initial PR #2076 merged, proving the first interpretation reached `main`.
- User clarification recorded separately without rewriting source history.
- Corrected branch contains updated root `AGENTS.md` and project traceability.
- Required CI / correction PR / final merge / canonical-main evidence: pending.

## Blockers / risks

- Until the correction PR merges, canonical `main` still contains the over-serial interpretation from #2076.
- Parallel work increases the need to keep each active task's branch/PR/evidence state distinct and current.

## Next action

Update WBS/acceptance/status/changelog to the clarified rule, open the correction PR, enable/enter the protected merge process, inspect required checks, merge, and verify canonical `main` before closing FPG-005.
