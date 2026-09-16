# TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001-REVIEW-001

- Project: `FAB-P0001 / TFI`
- Review role: independent code-review project group
- Reviewed task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement: `M6-PM-VEHC-R01`
- Acceptance: `M6-PM-VEHC-A01`
- Review timestamp: `2026-09-05T02:14Z` (`2026-09-05T10:14+08:00`)
- Product PR: `#2345`
- Frozen reviewed base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Frozen reviewed product head: `9c46c1d8f030be390995cc78f321aac0d96b7f44`
- Product state at review: `OPEN / UNMERGED / mergeable`
- Architecture records source: `#2340@9da26347e6de37a6576198b0f09d36928cbb1b0a`
- Execution handoff comment: `5548608629`
- Terminal review marker: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`

## Reviewer boundary

This review changes no product, workflow, test, Cargo/dependency, version, release, ruleset, or branch-protection file. Reviewer writes are restricted to `projects/telegram-fabushi-integration/**`. This session does not merge or enqueue #2345 and does not start packaged test release or stable release.

## Live repository facts independently re-read

- canonical `main` remains `dbf22b467d35c8af2a074896c355a41993c8c191`;
- #2345 base remains that canonical SHA and head remains `9c46c1d8f030be390995cc78f321aac0d96b7f44`;
- #2345 is OPEN / UNMERGED;
- exact commit ancestry is a four-commit fast-forward from base: `dbf22b... -> fd0c870928c766a41119759c6102d25a4d41cd5d -> 5c86cdc51fdabb5d4a3530de931becf1e97b75a4 -> 76174474fec9b3681fea7e1960f0fc468093d94c -> 9c46c1d8f030be390995cc78f321aac0d96b7f44`;
- active ruleset `main-merge-queue` (`15857448`) applies to `main`, requires `CI result`, uses merge queue / `ALLGREEN`, has no bypass actor and reports `current_user_can_bypass=never`;
- old #2341 `2241c856...`, #2342 `570b874...`, #2343 `bf62cd976...`, and failed records-only review #2344 `b60b8e248...` remain OPEN / UNMERGED provenance and were not modified.

## Exact changed-file audit

GitHub compare `dbf22... -> 9c46...` reports exactly 20 changed files and four commits.

### Allowed implementation/config files

1. `.github/workflows/ci.yml` — PASS. The only semantic changes are the unconditional canonical-version child, event-aware explicit checkout identity, post-checkout fail-closed HEAD assertion, unchanged canonical-script execution, and fail-closed aggregation into `CI result`.
2. `mobile/ios/project.yml` — PASS. The only semantic change is `CURRENT_PROJECT_VERSION: 28 -> 29`; `MARKETING_VERSION` remains `1.2.22`.

### Allowed TFI project records

The remaining 18 changed files are all under `projects/telegram-fabushi-integration/**`:

- `decisions/ADR-0014-event-aware-exact-head-checkout-gate.md`
- `docs/03-系统架构.md`
- `docs/04-领域模型与协议.md`
- `docs/05-Rust-Workspace与模块边界.md`
- `docs/19-完成定义与验收.md`
- `evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md`
- `evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-EXECUTION-2026-09-05.md`
- `management/01-WBS原子任务.md`
- `management/02-里程碑.md`
- `management/03-验收追踪矩阵.md`
- `management/04-风险登记.md`
- `management/05-状态报告.md`
- `management/06-依赖与阻塞.md`
- `management/07-变更日志.md`
- `management/08-问题与行动项.md`
- `management/89-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-架构诊断与执行交接.md`
- `management/90-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-执行验证与代码审查交接.md`
- `management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001.md`

No `app-version.json`, canonical assertion script, Android/Electron/Cargo/dependency file, application/test source, other workflow, release configuration, ruleset, branch-protection, root `AGENTS.md`, `projects/PORTFOLIO.json`, or unrelated project file is changed.

## Workflow semantic review

### `pull_request`

`.github/workflows/ci.yml` uses the event PR head (`github.event.pull_request.head.sha`) as the checkout identity for `pull_request`. After checkout, the job obtains `git rev-parse HEAD`, prints event/expected/actual identities, rejects empty expected identity, and exits non-zero on mismatch before running the canonical script. The automatic final-head raw log proves the actual resolved ref and worktree identity were the reviewed product head, not `refs/pull/2345/merge`.

### `merge_group`

The same event-aware expression selects `github.event.merge_group.head_sha` for `merge_group`, preserving validation of the current merge-queue group commit rather than substituting the individual PR head. Existing `merge_group: checks_requested` trigger remains present. Actual merge-group evidence is intentionally a downstream gate and has not been started by this review.

### `push` / `workflow_dispatch`

For non-PR/non-merge-group events the selector retains current `github.sha`. Existing trigger, permissions, classifier, sibling jobs and concurrency topology remain unchanged by this task.

### Required aggregate

`ci-result.needs` explicitly includes `canonical-version-contract`, runs under `if: always()`, reads `needs.canonical-version-contract.result`, and exits non-zero unless it is exactly `success`. Therefore canonical `skipped`, `neutral`, `cancelled`, or `failure` cannot satisfy the required aggregate. Existing diff-selected sibling semantics are preserved.

## Canonical script identity

`.github/scripts/assert-native-electron-canonical.sh` is absent from the PR diff. Independent base/head file readback reports the same blob SHA on both sides: `932693655177fe8a7192b0e350fbb2cc7f80ec05`. Version comparison logic is not duplicated in YAML; the unchanged script remains the sole version-contract implementation.

## iOS version review

Canonical base `app-version.json` is unchanged and reports:

- `version = 1.2.22`
- `androidVersionCode = 29`
- `iosBuildNumber = 29`

The final `mobile/ios/project.yml` diff changes only `CURRENT_PROJECT_VERSION: 28 -> 29`, leaving `MARKETING_VERSION: 1.2.22`. Final PR patch contains no formatting-wide or EOF noise in this product file. Result: canonical iOS build authority and generated-project mirror are aligned at 29.

## Exact final-head Actions evidence

Automatic CI run `33937479501` is a `pull_request` run, attempt 1, attached to #2345, with `head_sha=9c46c1d8f030be390995cc78f321aac0d96b7f44`, base `dbf22b...`, completed `success`.

### Canonical child — job `101228105692`

Raw decoded job log independently proves, in order:

1. `actions/checkout@v5` input `ref: 9c46c1d8f030be390995cc78f321aac0d96b7f44`;
2. fetch of exact SHA `9c46...`;
3. `git checkout --force 9c46...`;
4. `HEAD is now at 9c46c1d docs(tfi): record exact-head checkout execution`;
5. `git log -1 --format=%H` -> full `9c46c1d8f030be390995cc78f321aac0d96b7f44`;
6. identity step runs `actual_head="$(git rev-parse HEAD)"` with `EXPECTED_HEAD_SHA=9c46...`;
7. raw output: `canonical-version-contract event=pull_request expected_head=9c46c1d8f030be390995cc78f321aac0d96b7f44 actual_head=9c46c1d8f030be390995cc78f321aac0d96b7f44`;
8. only after that proof, `bash .github/scripts/assert-native-electron-canonical.sh` executes and succeeds.

The prior #2343 synthetic merge `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac` is not used as current acceptance evidence.

### Required aggregate — job `101228236513`

Same-run raw decoded log independently proves `version_contract_result="success"`, then executes a fail-closed branch that exits non-zero for any value other than exact `success`. The job prints `Diff-selected canonical architecture CI checks passed.` and completes SUCCESS.

### Other final-head automatic workflows

All observed automatic pull-request workflows on `9c46...` are completed SUCCESS: Project portfolio governance `33937479392`, Native mobile quality gate `33937479393`, Developer Fiat Commerce `33937479394`, Explicit automerge `33937479397`, Computer control security gate `33937479417`, and CI `33937479501`.

## Open-source-first / security review

GitHub official event documentation confirms that normal `pull_request` default identity is the PR merge branch/merge commit and that `github.event.pull_request.head.sha` is the documented way to target the head commit. GitHub official `merge_group` documentation defines `GITHUB_SHA` as the merge-group SHA and requires the separate event for merge-queue required checks. The implementation matches those semantics.

Security review found no new secret, write permission, PAT, third-party action, release credential, or privileged `pull_request_target` use. Workflow permissions remain read-only (`contents/actions/checks/pull-requests: read`), checkout uses `persist-credentials: false`, and the raw job log confirms read-only token permissions. Executing PR-head content therefore remains within ordinary `pull_request` CI trust boundaries rather than a privileged secret-bearing trigger.

Non-blocking supply-chain observation: the workflow retains repository-existing `actions/checkout@v5` major-tag usage rather than a full immutable action SHA. GitHub recommends full SHA pinning as the strongest supply-chain posture, but this task does not introduce a new action/dependency and the automatic reviewed run resolved checkout to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`. Changing repository-wide action pinning is outside this frozen atomic scope and is not required by `M6-PM-VEHC-A01`.

## Findings

- `BLOCKER / HIGH / MEDIUM`: none.
- `INFO / NON-BLOCKING`: existing major-tag action pinning is weaker than full-SHA pinning; not introduced by this task and not an acceptance defect for this atomic review.

## Acceptance disposition

All PR-stage clauses of `M6-PM-VEHC-A01` are satisfied for exact immutable `#2345@9c46c1d8f030be390995cc78f321aac0d96b7f44`.

`REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`

This PASS authorizes only the next **protected canonical-main merge gate** for the exact unchanged product head. It does not authorize direct merge, bypass, this reviewer entering merge queue, packaged test release, or stable release.

Any later #2345 commit invalidates this review and requires fresh automatic exact-head evidence plus a new independent review.

## Remaining downstream gates

1. Test-release project group, in its existing project tab/new chat, may take exact unchanged #2345 into the protected merge queue.
2. The resulting automatic `merge_group` run must prove actual worktree HEAD equals the current merge-group SHA, then unchanged canonical script SUCCESS and same-group required `CI result` SUCCESS.
3. After protected merge, canonical `main` must be re-read and must contain accepted event-aware topology, unchanged canonical script, `iosBuildNumber=29`, and `CURRENT_PROJECT_VERSION=29`.
4. Packaged test release remains blocked by separately frozen MAINSAFE fixture/evidence prerequisites even after this repository gate lands; stable release is later and independent.
