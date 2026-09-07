# VERSION-EXACT-HEAD-CHECKOUT independent review evidence — 2026-09-05

## Review identity

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Review time: `2026-09-05T02:14Z` / `2026-09-05T10:14+08:00`
- Product PR: `#2345`
- Exact base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Exact reviewed head: `9c46c1d8f030be390995cc78f321aac0d96b7f44`
- Product state: `OPEN / UNMERGED`
- Architecture source: `#2340@9da26347e6de37a6576198b0f09d36928cbb1b0a`
- Execution handoff: `#2345` comment `5548608629`
- Reviewer result: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`

## Live fact evidence

### Repository / PR topology

Independent GitHub readback:

- canonical `main` -> `dbf22b467d35c8af2a074896c355a41993c8c191`;
- #2345 base -> same `dbf22...`;
- #2345 head -> `9c46c1d8f030be390995cc78f321aac0d96b7f44`;
- #2345 state -> OPEN, merged=false, mergeable=true;
- compare base...head -> `ahead_by=4`, `behind_by=0`, 20 changed files.

Commit chain:

1. `fd0c870928c766a41119759c6102d25a4d41cd5d` — `ci(tfi): validate canonical gate on event exact head`
2. `5c86cdc51fdabb5d4a3530de931becf1e97b75a4` — `fix(tfi): align iOS build number with canonical version`
3. `76174474fec9b3681fea7e1960f0fc468093d94c` — `chore(tfi): preserve iOS project file formatting`
4. `9c46c1d8f030be390995cc78f321aac0d96b7f44` — `docs(tfi): record exact-head checkout execution`

All form a direct fast-forward lineage from `dbf22...`; no historical product/review PR is part of this lineage.

### Historical provenance preserved

Live re-read confirms all remain OPEN / UNMERGED and unchanged for this review:

- #2341 `2241c856fb3da498ac99ade89007fe01dd335183`
- #2342 `570b874318bfe42406c6f46f51798baed8c89e48`
- #2343 `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`, synthetic merge provenance `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`
- #2344 records-only review `b60b8e2483333db21ca6cea068b7a1be9c0f4851`

#2344 remains the binding failure record for the superseded bootstrap candidate only; its synthetic-merge green evidence is not reused here.

## Per-file diff evidence

GitHub compare reports exactly these 20 files:

| Path | Diff summary | Reviewer |
|---|---:|---|
| `.github/workflows/ci.yml` | +59/-0 | PASS — exact-head orchestration + aggregate propagation only |
| `mobile/ios/project.yml` | +1/-1 | PASS — only build 28 -> 29 |
| `projects/telegram-fabushi-integration/decisions/ADR-0014-event-aware-exact-head-checkout-gate.md` | +67 | PASS — task architecture record |
| `projects/telegram-fabushi-integration/docs/03-系统架构.md` | +12 | PASS — evidence identity boundary |
| `projects/telegram-fabushi-integration/docs/04-领域模型与协议.md` | +9 | PASS — explicitly no product-protocol scope expansion |
| `projects/telegram-fabushi-integration/docs/05-Rust-Workspace与模块边界.md` | +9 | PASS — explicitly no Rust/Cargo scope expansion |
| `projects/telegram-fabushi-integration/docs/19-完成定义与验收.md` | +28/-1 | PASS — exact-head/merge-group DoD record |
| `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md` | +95 | PASS |
| `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-EXECUTION-2026-09-05.md` | +76 | PASS |
| `projects/telegram-fabushi-integration/management/01-WBS原子任务.md` | +8 | PASS |
| `projects/telegram-fabushi-integration/management/02-里程碑.md` | +38 | PASS |
| `projects/telegram-fabushi-integration/management/03-验收追踪矩阵.md` | +13 | PASS |
| `projects/telegram-fabushi-integration/management/04-风险登记.md` | +35/-1 | PASS |
| `projects/telegram-fabushi-integration/management/05-状态报告.md` | +14/-1 | PASS |
| `projects/telegram-fabushi-integration/management/06-依赖与阻塞.md` | +41/-3 | PASS |
| `projects/telegram-fabushi-integration/management/07-变更日志.md` | +13 | PASS |
| `projects/telegram-fabushi-integration/management/08-问题与行动项.md` | +32/-1 | PASS |
| `projects/telegram-fabushi-integration/management/89-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-架构诊断与执行交接.md` | +150 | PASS |
| `projects/telegram-fabushi-integration/management/90-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-执行验证与代码审查交接.md` | +39 | PASS |
| `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001.md` | +196 | PASS |

Forbidden paths are absent. In particular, no `app-version.json`, `.github/scripts/assert-native-electron-canonical.sh`, Android/Electron/Cargo/dependency, other workflow, product/test source, release configuration, ruleset, or branch-protection file changed.

## Workflow semantic evidence

### Source behavior

The reviewed `canonical-version-contract` job:

- runs unconditionally under the existing CI trigger set;
- checks out explicit `github.event.pull_request.head.sha` for `pull_request`;
- checks out `github.event.merge_group.head_sha` for `merge_group`;
- otherwise uses current `github.sha` for existing push/dispatch semantics;
- uses `persist-credentials: false`;
- performs sparse checkout of the canonical script and its direct inputs;
- obtains `actual_head=$(git rev-parse HEAD)` and fails on empty expected SHA or mismatch;
- only then executes `bash .github/scripts/assert-native-electron-canonical.sh`.

The reviewed `CI result`:

- adds `canonical-version-contract` to `needs`;
- keeps `if: always()`;
- rejects every canonical child result except exact `success` before evaluating pre-existing diff-selected sibling jobs.

No version comparisons are duplicated in YAML.

### Canonical script byte identity

Base and final-head readback of `.github/scripts/assert-native-electron-canonical.sh` both produce blob:

`932693655177fe8a7192b0e350fbb2cc7f80ec05`

The script is not in the PR diff.

## iOS evidence

Canonical base `app-version.json`:

```text
version=1.2.22
androidVersionCode=29
iosBuildNumber=29
```

Final PR patch for `mobile/ios/project.yml`:

```diff
 MARKETING_VERSION: 1.2.22
-CURRENT_PROJECT_VERSION: 28
+CURRENT_PROJECT_VERSION: 29
```

No other semantic or formatting change exists in that file's final patch.

## Exact automatic Actions evidence

### CI run `33937479501`

Live run metadata:

- workflow: `CI`
- event: `pull_request`
- run attempt: `1`
- PR: `#2345`
- head SHA: `9c46c1d8f030be390995cc78f321aac0d96b7f44`
- base SHA: `dbf22b467d35c8af2a074896c355a41993c8c191`
- status/conclusion: `completed / success`

### Raw canonical child `101228105692`

Decoded raw log proof:

```text
ref: 9c46c1d8f030be390995cc78f321aac0d96b7f44
...
git fetch ... origin 9c46c1d8f030be390995cc78f321aac0d96b7f44
...
git checkout --progress --force 9c46c1d8f030be390995cc78f321aac0d96b7f44
...
HEAD is now at 9c46c1d docs(tfi): record exact-head checkout execution
...
git log -1 --format=%H
9c46c1d8f030be390995cc78f321aac0d96b7f44
...
EXPECTED_HEAD_SHA: 9c46c1d8f030be390995cc78f321aac0d96b7f44
...
canonical-version-contract event=pull_request expected_head=9c46c1d8f030be390995cc78f321aac0d96b7f44 actual_head=9c46c1d8f030be390995cc78f321aac0d96b7f44
...
Run bash .github/scripts/assert-native-electron-canonical.sh
...
Electron desktop + native SwiftUI/Compose + shared Rust Host is the canonical application architecture.
```

This is exact product-head proof. There is no `refs/remotes/pull/2345/merge` checkout in the acceptance path.

The same raw log reports `GITHUB_TOKEN` permissions `Actions: read`, `Checks: read`, `Contents: read`, `PullRequests: read` and checkout `persist-credentials: false`.

### Raw required aggregate `101228236513`

Decoded same-run log:

```text
version_contract_result="success"
if [ "$version_contract_result" != "success" ]; then
  echo "Canonical version contract failed: $version_contract_result"
  exit 1
fi
...
Diff-selected canonical architecture CI checks passed.
```

Result: required aggregate succeeds only after exact canonical child success.

### Other final-head automatic runs

- `33937479392` Project portfolio governance — SUCCESS
- `33937479393` Native mobile quality gate — SUCCESS
- `33937479394` Developer Fiat Commerce — SUCCESS
- `33937479397` Explicit automerge — SUCCESS
- `33937479417` Computer control security gate — SUCCESS
- `33937479501` CI — SUCCESS

No manual dispatch, rerun-only acceptance, historical SHA, sibling substitution, skipped/neutral canonical child, or #2343 synthetic merge is used.

## Ruleset evidence

Ruleset `15857448 / main-merge-queue` is `active` for `refs/heads/main`:

- merge method: `SQUASH`
- grouping strategy: `ALLGREEN`
- required status: `CI result`
- bypass actors: none
- `current_user_can_bypass=never`

Review does not mutate this control plane.

## Open-source-first evidence

GitHub official documentation states that normal open `pull_request` workflows use the PR merge branch/merge commit by default and explicitly recommends `github.event.pull_request.head.sha` when only the PR head is required. GitHub official `merge_group` documentation states `GITHUB_SHA` is the merge-group SHA and that the separate event is required for merge-queue checks. The implementation matches those official semantics and retains the repository-existing `actions/checkout@v5` dependency.

Security posture for this task is least-privilege: regular `pull_request`, not privileged `pull_request_target`; read-only workflow permissions; no explicit secret use; `persist-credentials:false`.

Supply-chain INFO: repository-existing major-tag `actions/checkout@v5` is not full-SHA pinned. The reviewed run resolved it to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`; no new action/dependency is introduced. Full-SHA pinning is a separate repository-wide hardening opportunity, not a blocker for this frozen task.

## Reviewer findings and disposition

- Blocker / High / Medium findings: **none**.
- Info / non-blocking: existing checkout major tag could be hardened to immutable SHA in a separately scoped governance/security task.

All PR-stage hard gates are satisfied for immutable `#2345@9c46c1d8f030be390995cc78f321aac0d96b7f44`.

**Terminal result: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`.**

Authorized next gate: protected canonical-main merge gate for exact unchanged #2345, owned by the test-release project group. Reviewer does not enqueue or merge.

Still not authorized: packaged test release and stable release. The queue must first produce fresh `merge_group` raw exact-group-SHA proof, required aggregate success, protected merge, and canonical-main readback; broader MAINSAFE fixture/evidence blockers remain separate.
