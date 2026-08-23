# FPG-005 — Parallel PR execution with PR-to-main completion gate

- Project ID: `FAB-P0002`
- Project Key: `FPG`
- Task ID: `FPG-005`
- Original source: `source/2026-08-24-FPG-005-pr-main-serialization.md`
- Clarification source: `source/2026-08-24-FPG-005-parallel-pr-clarification.md`
- Status: `passed`
- Started: `2026-08-24`
- Updated: `2026-08-24`
- Completed: `2026-08-24`

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

All acceptance criteria passed.

## Verification

- GitHub PR diff review: passed.
- Repository CI run `32652232551`: `success`.
- Project portfolio governance run `32652232596`: `success`.
- Explicit automerge run `32652232562`: `success`.
- Protected merge/merge queue: PR #2077 merged.
- Post-merge canonical `main` readback: `AGENTS.md` section 1B verified; blob `b76cf3e85584cb7144190bf37d0edef2474a2fcc`.

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
- Final correction head: `227931d3688119d1affd77ee11acc1330592c29e`
- Correction PR: `#2077`
- Required CI: run `32652232551` success.
- Project portfolio governance: run `32652232596` success.
- Protected merge: merge commit `faef2af404dd7e89db4bcaf9f417369566c179c3`.
- Canonical-main readback: corrected `AGENTS.md` section 1B present on `main`.

## Implementation summary

Root `AGENTS.md` now defines parallelism as normal: multiple independent tasks/PRs may advance concurrently, especially during CI/review/merge waits. The strict rule is at the completion boundary: each task must return to its own PR, resolve blockers where possible, merge through protected `main`, and verify canonical `main` before that task can be declared finished.

## Evidence

- Initial PR #2076 preserved as historical evidence of the superseded strict-serialization interpretation.
- User clarification is recorded separately without rewriting source history.
- PR #2077 corrected the repository-wide rule.
- All required checks for #2077 passed.
- PR #2077 merged to `main` as `faef2af404dd7e89db4bcaf9f417369566c179c3`.
- Canonical `main` readback confirms the corrected parallel-work/per-task-closure rule is active.

## Blockers / risks

- None for FPG-005.
- Operational note: parallel work increases the need to keep each active task's branch/PR/evidence state distinct and current.

## Next action

FPG-005 is functionally complete. Future Fabushi repository tasks may proceed in parallel, but each individual task must satisfy its own PR-to-main merge and canonical-main verification gate before being marked or reported complete.
