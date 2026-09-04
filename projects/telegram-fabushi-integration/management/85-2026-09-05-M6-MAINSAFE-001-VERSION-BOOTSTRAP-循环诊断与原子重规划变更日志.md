# 85 — TFI-M6-MAINSAFE-001 VERSION-BOOTSTRAP 循环诊断与原子重规划变更日志 — 2026-09-05

This record covers Architecture/governance work only. No product, workflow, script, test, Cargo/dependency, ruleset, release, or version implementation was changed by this session.

## Live reads completed

1. Re-read canonical GitHub `main`: `dbf22b467d35c8af2a074896c355a41993c8c191`.
2. Re-read root `AGENTS.md`, `projects/PORTFOLIO.json`, `projects/PROJECT_ID_POLICY.md`, TFI `SOURCE_OF_TRUTH.md`, `PROJECT.yaml`, `README.md`.
3. Re-read #2340/#2341/#2342 live PR metadata, exact heads, states and changed-file sets.
4. Re-read #2341 blocker comment `5547296411` and former architecture handoff `5547466413`.
5. Re-read #2342 blocker/architecture-return comment `5547556953` and final CI run `33928934236` / jobs.
6. Verified #2342 child `101203371687` actually executed and failed, while aggregate `CI result` `101203476417` failed; durable execution evidence records the raw command/error strings.
7. Re-read canonical and #2342 `ci.yml`, canonical `.github/scripts/assert-native-electron-canonical.sh`, `app-version.json`, `mobile/ios/project.yml`.
8. Re-read live ruleset `15857448`: active merge queue, required status exactly `CI result`, no bypass actor.
9. Re-read historical `VERSION-CONTRACT-001`, planned `VERSION-GUARD-CI-001`, planned `VERSION-CONTRACT-002`, their execution/evidence/status records, M6 WBS, milestone, acceptance, risk, dependency/blocker and actions records.
10. Re-read Fabushi FCM ADR-0005 and official/open-source GitHub Actions provenance.

## Architecture decision

The previous sequential plan is superseded because it cannot self-bootstrap under the protected required gate:

- guard-only first is truthfully red against canonical 29/28 drift;
- version-only first cannot satisfy the frozen required guard evidence because its base lacks the topology.

Architecture therefore freezes one atomic same-head bootstrap task:

`TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`

with implementation/config allowlist exactly `.github/workflows/ci.yml` + `mobile/ios/project.yml` 28 -> 29, plus task-specific TFI records.

## Records written / synchronized

- added task `management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`;
- added diagnosis evidence `evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`;
- added ADR `decisions/ADR-0013-version-bootstrap-atomic-required-gate.md`;
- added dated status/acceptance record `84-2026-09-05-M6-MAINSAFE-001-VERSION-BOOTSTRAP-循环诊断与原子重规划状态与验收.md`;
- added this dated changelog;
- synchronized M6 WBS, milestone, post-main acceptance matrix, risk register, dependency/blocker register, issues/actions, historical task disposition, ADR/evidence indexes.

## Open-source-first / official-source decision

Adopted GitHub official semantics for `needs`, `needs.<job>.result`, required status checks and merge queue `merge_group`; retained repository `actions/checkout` and `actions/github-script`, both MIT; reused Fabushi FCM ADR-0005 merge-queue/aggregate precedent. No upstream code was copied and no new dependency was introduced by Architecture.

Rejected: manual dispatch/rerun closure, optional status substitution, skipped/neutral child acceptance, bootstrap special-case, ruleset/branch-protection change, canonical-script change, duplicated version logic, or merging either old PR as a shortcut.

## Explicit non-actions

- no `.github/**` or product file changed by Architecture;
- no app/test source, Cargo/dependency, version/release implementation changed;
- no local build/test run;
- no product/CI replacement PR created;
- no code review performed;
- no protected merge attempted;
- no test release or stable release started;
- #2341/#2342 were not merged, rebased, retargeted, force-pushed or closed by Architecture.

## Next-only authorization

After final architecture readback, the only task allowed to enter a new Execution session is `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`. All downstream groups remain paused until its exact-head, independent-review, merge-group and canonical-main readback gates are satisfied.