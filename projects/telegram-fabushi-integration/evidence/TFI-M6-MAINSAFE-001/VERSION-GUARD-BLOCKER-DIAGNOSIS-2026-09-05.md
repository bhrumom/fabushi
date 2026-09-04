# TFI-M6-MAINSAFE-001 version-guard blocker diagnosis — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture records PR: `#2340`
- Blocked product PR: `#2341`
- Blocked product exact head: `2241c856fb3da498ac99ade89007fe01dd335183`
- Execution blocker handoff: `#2341` comment `5547296411`
- Diagnosis: `CI/GOVERNANCE VERSION-GUARD TOPOLOGY GAP`, not a demonstrated product-patch failure.

## 1. #2341 product fact

PR #2341 is still OPEN / UNMERGED and is based on canonical `dbf22b467d35c8af2a074896c355a41993c8c191`. Its five changed files are exactly:

1. `mobile/ios/project.yml`
2. `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-CONTRACT-001-EXECUTION-2026-09-05.md`
3. `projects/telegram-fabushi-integration/management/78-2026-09-05-M6-MAINSAFE-001-VERSION-CONTRACT-001-执行状态与验收.md`
4. `projects/telegram-fabushi-integration/management/79-2026-09-05-M6-MAINSAFE-001-VERSION-CONTRACT-001-执行变更日志.md`
5. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001-execution-2026-09-05.md`

The only product/config semantic patch is `mobile/ios/project.yml` `CURRENT_PROJECT_VERSION: 28 -> 29`. This matches the frozen one-file allowlist. There is no evidence in this round that the one-line product patch itself is wrong.

## 2. Exact-head Actions readback

The final exact head `2241c856fb3da498ac99ade89007fe01dd335183` has exactly five automatically associated PR workflows, all SUCCESS:

- CI `33926840519`
- Native mobile quality gate `33926840551`
- Project portfolio governance `33926840613`
- Developer Fiat Commerce `33926840526`
- Explicit automerge `33926840543`

This green set is **not** version-guard evidence.

### CI job named `Canonical architecture guardrails`

CI job `101198143445` checks out only `/.github/workflows/**`. Its only substantive step is `Reject retired Flutter/Tauri/Capacitor workflows and commands`. The raw log does not fetch or execute `.github/scripts/assert-native-electron-canonical.sh`.

Therefore the job name must not be used as evidence that the canonical version contract was checked.

### Native mobile PR fast path

Run `33926840551`, job `101197157268`, succeeds after PR diff/whitespace checks, Rust formatting, and native manifest existence. All heavyweight Android/iOS build, XcodeGen, simulator, UI-test and native result-artifact steps are explicitly `skipped` on the pull-request fast path.

Therefore Native mobile SUCCESS must not be represented as iOS build/version guard execution.

## 3. Authoritative guard and topology

`.github/scripts/assert-native-electron-canonical.sh` is the authoritative repository guard for this version contract. It reads canonical `app-version.json`, validates desktop/mobile package versions, reads `mobile/ios/project.yml`, and fails unless `CURRENT_PROJECT_VERSION == app-version.json.iosBuildNumber`.

The script is executed by the Electron desktop/release family, including `.github/workflows/electron-desktop.yml`. However Electron desktop PR `paths` do not include `mobile/ios/project.yml` or the canonical version source set, so #2341 did not create an Electron workflow run.

More importantly, live ruleset `main-merge-queue` id `15857448` requires only the status `CI result`. `CI result` currently aggregates classifier/frontend/worker/MCP/workflow-guardrails/Electron-Feature-Host jobs, but no canonical version-contract job. Thus a PR may produce a successful protected required status while the authoritative version script never runs.

This is the root blocker.

## 4. Why manual dispatch/rerun is not the repair

- The current connected GitHub Actions capability can re-run an existing run/job but exposes no workflow-dispatch operation. There is no Electron run for exact head `2241c856...` to re-run.
- GitHub officially supports `workflow_dispatch` for workflows configured with it and permits choosing a branch/ref. That can be useful for diagnosis, but it does not repair automatic PR gate topology and is not the repository's required `CI result`.
- A manually dispatched success, or a non-required Electron status, cannot substitute for a version-contract child gate of the required aggregate.

Decision: do not unblock #2341 with manual evidence substitution.

## 5. Minimal durable repair

Freeze two sequential tasks:

1. `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
   - change only `.github/workflows/ci.yml`;
   - add a dedicated diff-selected canonical version-contract job that invokes the existing `.github/scripts/assert-native-electron-canonical.sh` without copying its checks;
   - include that job in `CI result` dependencies/aggregation;
   - preserve `pull_request`, `merge_group`, `push`, unknown-path fail-safe and the protected `CI result` name.
2. `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002`
   - only after task 1 is protected-merged and canonical-read back;
   - create a fresh main-based product PR whose only semantic change is `mobile/ios/project.yml` `28 -> 29`;
   - require the newly wired version-contract job to **run (not skip)** and succeed on that exact product head, with `CI result` also succeeding.

Merely adding `mobile/ios/project.yml` to `electron-desktop.yml` is rejected as the primary repair: it would trigger a non-required heavier workflow but would not place the canonical version assertion inside the repository's sole protected required status.

## 6. #2341 disposition

`TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` and PR #2341 remain **BLOCKED / UNREVIEWED / UNMERGED**. They are retained as truthful implementation/blocker evidence and are not closed, rebased, force-pushed, reviewed or merged by architecture.

After `VERSION-GUARD-CI-001` lands on canonical main, execution must start `VERSION-CONTRACT-002` from that newly read-back main rather than resume #2341. Once the replacement PR exists and its provenance is recorded, #2341 may be closed by the appropriate owner as superseded, never merged as a shortcut.

## 7. Open-source / official review

| Source | Authority / license | Adopt | Reject / no-copy rule |
|---|---|---|---|
| GitHub Actions workflow syntax / path filters | GitHub official documentation | path selection semantics and PR exact-diff behavior | documentation semantics only; no copied implementation |
| GitHub required status checks + merge queue docs | GitHub official documentation | latest-SHA required-check discipline; merge-group trigger for required Actions | no status injection or non-required evidence substitution |
| GitHub manual workflow docs | GitHub official documentation | `workflow_dispatch` as diagnostic/manual mechanism | rejected as durable automatic PR-gate replacement |
| `actions/github-script` | GitHub-maintained action, MIT | retain the repository's existing classifier approach where useful | no new dependency and no upstream code copy |
| FCM ADR-0005 fail-fast/warm-state CI | first-party Fabushi governance precedent | preserve diff-selected cheap gates, aggregate `CI result`, merge queue, unknown-path fail-safe | reject expensive all-platform PR validation where a deterministic lightweight guard suffices |

No new TFI product ADR is required: this round does not change product architecture or version authority; it restores enforcement of an already canonical repository script through the existing protected CI aggregation model. Task/evidence records are sufficient, while FCM ADR-0005 remains the applicable CI-governance precedent.

## 8. Stop rules

- Never treat `Canonical architecture guardrails` as the version guard unless the actual script is shown in raw job steps/logs.
- Never treat skipped heavy Native mobile steps as executed.
- Never inject/forge a status or use a previous head's success.
- If `.github/workflows/ci.yml` alone cannot make the version guard an automatic required aggregate child, stop and return to architecture before expanding workflow scope.
- No product/test/workflow implementation is performed by this architecture records PR.
