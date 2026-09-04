# 86 — 2026-09-05 M6 MAINSAFE VERSION-BOOTSTRAP execution status and acceptance

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Requirement / Acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`
- Canonical execution base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Replacement PR: `#2343`
- Product/bootstrap commit: `496ddefc0866f2d0568d0c3d618cfcede2e6c98c`
- State at record commit: `IMPLEMENTED / FINAL-EXACT-HEAD-ACTIONS-PENDING`

## Execution status

The dependency cycle diagnosed by Architecture is being resolved as one atomic fresh-main transaction. The two implementation/config changes are exactly:

- `.github/workflows/ci.yml`: install the already-proven `Canonical version contract` child and make required `CI result` require exact child `success`, reusing the unchanged canonical script;
- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION 28 -> 29` only.

Task-specific records are the only additional changed paths.

No script, ruleset, other workflow, `app-version.json`, Android, Electron, application/test source, Cargo/dependency, release/version logic, fixture/evidence journey, ownership or other MAINSAFE implementation is included.

## Acceptance matrix

| Acceptance item | Required truth | State at record creation | Evidence source |
|---|---|---|---|
| Fresh canonical base | branch created from exact current `main` | PASS | GitHub readback `dbf22b467d35c8af2a074896c355a41993c8c191` |
| Historical state | #2341/#2342 remain open/unmerged at frozen exact heads | PASS | #2341 `2241c856...`; #2342 `570b874...` |
| Replacement lineage | new PR, not old PR reuse | PASS | PR #2343, branch `fix/tfi-m6-mainsafe-001-version-bootstrap-001` |
| CI topology | independent canonical child executes unchanged script | IMPLEMENTED / ACTIONS PENDING | `.github/workflows/ci.yml` + final-head Actions |
| iOS mirror | only `CURRENT_PROJECT_VERSION 28 -> 29` | IMPLEMENTED | `mobile/ios/project.yml` |
| Canonical script unchanged | no script diff | PASS BY DIFF / ACTIONS PENDING | PR changed-files + final-head child log |
| Required aggregate | `CI result` depends on child and requires exact `success` | IMPLEMENTED / ACTIONS PENDING | workflow diff + final-head Actions |
| No bypass evidence | no skip/neutral/manual/rerun/different SHA substitution | ENFORCED | task contract + live Actions |
| Other applicable PR gates | portfolio / commerce / explicit PR gate truthful success | PENDING | final exact-head workflow runs |
| Independent code review | exact final head reviewed by separate group | NOT STARTED — NEXT ONLY AFTER EXECUTION PASS | future code-review session |
| Protected merge-group | child + CI result success on `merge_group` | NOT STARTED / OUTSIDE EXECUTION SESSION | future post-review merge queue |
| Canonical main readback | accepted topology + 29/29 after protected merge | NOT STARTED / OUTSIDE EXECUTION SESSION | future post-merge readback |
| Test/stable release | remains blocked by later MAINSAFE prerequisites | BLOCKED / NOT STARTED | project dependency records |

## Risks and dependencies

- The former split sequence is superseded; do not resume `VERSION-GUARD-CI-001` or `VERSION-CONTRACT-002` as separate execution.
- PR-head success is necessary but not sufficient for protected merge; merge-group proof remains a later code-review/merge-queue gate.
- If the canonical child is absent, skipped, neutral or fails on #2343 final head, execution stops BLOCKED; no ruleset/script special case is permitted.
- #2341/#2342 are historical provenance only. They remain open in this execution even though replacement provenance now exists.

## Milestone and next action

M6 MAINSAFE version-bootstrap is at `IMPLEMENTED / FINAL-EXACT-HEAD-ACTIONS-PENDING`. It is not merged, tested-release, or released.

Only if the final exact #2343 head obtains the required automatic success evidence may execution hand off that exact head to an independent code-review project-group session. No code review is performed here.
