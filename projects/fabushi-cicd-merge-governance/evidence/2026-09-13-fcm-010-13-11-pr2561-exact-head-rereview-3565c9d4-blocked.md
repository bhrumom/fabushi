# FCM-010.13.11 independent exact-head re-review — PR #2561 @ 3565c9d4 — BLOCKED

- Repository: `bhrumom/fabushi`
- Project: `FAB-P0003 / FCM`
- Atomic task: `FCM-010.13.11-unread-deselect-governance-repair`
- Product PR: `#2561`
- Exact reviewed product head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Exact reviewed PR base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- Current canonical main observed independently during review: `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`
- Review mode: records-only; no product/test/workflow/dependency/version mutation, no CI rerun, no ready/merge/release/dispatch
- Disposition: **REVIEW-BLOCKED**
- Findings: **P0=0 / P1=1 / P2=0 / other-blocking=1**

This record is a fresh independent re-review. It supersedes the earlier `REVIEW-PASS` disposition in this records PR for merge-authorization purposes because later exact-head facts expose blocking review inputs. The older file remains historical evidence only and must not authorize PR #2561.

## Immutable specification binding

The live specification manifest is the existing reviewer-record manifest, serialized exactly as `<path>\t<git_blob_sha>\n`, lexicographically sorted by path:

```text
projects/fabushi-cicd-merge-governance/SOURCE_OF_TRUTH.md	a0f02dc787d9005e4b2ea781766243a962ab6872
projects/fabushi-cicd-merge-governance/docs/02-需求与成功指标.md	98b9fbbe00bdeafd87a3b767eb730405213a1bae
projects/fabushi-cicd-merge-governance/docs/19-完成定义与验收.md	16255a2e702da2a8b04519aa46f0425da5e861af
projects/fabushi-cicd-merge-governance/management/01-WBS原子任务.md	7e5068102bf72a61c9e2dfe7884d90f71d6774db
projects/fabushi-cicd-merge-governance/management/03-验收追踪矩阵.md	fad9e0d4384bd960015bd8b66692f3c07f0ee6b2
projects/fabushi-cicd-merge-governance/management/04-风险登记.md	8ee79e9fb39f6ca03531a0329ba97f8ae24c2845
projects/fabushi-cicd-merge-governance/management/05-状态报告.md	9d1e21fa81f3016f4e80393c68cb5c1d30701637
projects/fabushi-cicd-merge-governance/management/06-依赖与阻塞.md	03f9c7dea1a13b16bea819030d3b70ea017f64f6
projects/fabushi-cicd-merge-governance/management/07-变更日志.md	9d238fca52b459410090a6302e1b22c3acbb0086
projects/fabushi-cicd-merge-governance/management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md	85c4fd7bf2325fc69e0002b5bcde9f0feb775d86
```

- `spec_digest = 391e7a3ee4bda068398ff166f45371391a877d728ebc16e4fe96802a4a310307`
- `review_key = 037fe69d1c84279ffc971208c3454ba7bb5bf9c68a3bc63d9093a3ba0b5d8918`

The review key is SHA-256 over the repository, PR number, exact head, exact base, atomic task id `FCM-010.13.11`, and the above spec digest using the repository's existing canonical reviewer-record serialization.

## Independent code review result

No new blocking product-code defect was found in the exact current diff after independently checking the Rust provider/Runtime/FeatureHost and Electron transport boundaries.

- `KernelConversationProvider` owns authoritative unread state with a per-conversation read boundary; persisted visible history initializes each conversation at read state; only assistant messages after that conversation's boundary count unread.
- Hidden sends/completions remain available to runtime callers but do not enter the visible provider history/persistence or unread count; visible user messages do not count unread.
- Production `conversation.open` requests history limit `200`; the background indexing request is `2_000` and Runtime clamps it to `500`; the provider acknowledges read only on the explicit-open `200` compatibility contract. The exact-head cross-layer regression exercises the real FeatureHost production adapter -> MahayanaHost -> Runtime clamp -> Kernel provider path, including unrelated shared-provider conversation open, background history, hidden completion, and explicit assistant open.
- Electron refreshes authoritative `conversation.list` after accepted non-Mini-App `conversation.open` and after assistant `chat.message`; the EventTarget regression drives the real command observer/transport lifecycle rather than calling the observer helper directly.
- The added Cargo manifest/lockfile delta is test-support/dev-dependency plumbing for the cross-layer regression and does not introduce a new external package version/source.
- The open-source-first evidence surveys Matrix Rust SDK, Signal Desktop and Mattermost, records architecture/data/testing/operations/security/maintenance/license/compatibility decisions, and explicitly rejects source/dependency reuse where license or fit is inappropriate.
- The changed state mutex is not held across async awaits in the new completion/history mutation path; reset clears history and per-conversation read boundaries. Existing source/device/generation/find/logout/evidence gates are not weakened by this PR.

Exact-head Actions are genuine head-bound evidence: `CI` run `34704136588` has `CI result` success on exact head; `Mahayana fast checks` `34704136567` succeeds including the production feature-adapter step; `Global Dharma Rust` `34704136681` succeeds its Mahayana locked test path; `Electron desktop quality gate` `34704136680` succeeds the PR Electron path/result. PR-inapplicable release/publish jobs that are skipped are not counted as production acceptance.

## P1-1 — durable FCM task/project record does not reconstruct the reviewed exact head

**Files / locations**

- `projects/fabushi-cicd-merge-governance/management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md` — top-level `Status`, `Current repair PR`, `Current blockers / risks`, `Next action`.
- `projects/fabushi-cicd-merge-governance/management/01-WBS原子任务.md` — `FCM-010.13.11` row.
- `projects/fabushi-cicd-merge-governance/management/04-风险登记.md` — `FCM-RSK-014` / live trigger.
- `projects/fabushi-cicd-merge-governance/management/06-依赖与阻塞.md` — `FCM-D015` / current closure state.
- Associated acceptance/status/changelog records must remain consistent with the same facts.

**Fact**

The live PR is exact head `3565c9d4...`, with 17 commits and 13 changed files, and its exact-head PR-side workflow set is already complete/success for the applicable paths. The task record still says the latest implementation commit before record update is `4e064e7c...`, says a new exact-head CI cycle is required / the final exact head has not passed required CI, and its current blocker/next-action text is still written around the earlier `2e65a0a6...` P1/P2 review plus `25f95c1f...` repair. WBS/risk/dependency records likewise describe the cross-layer regression as being added or CI/re-review as pending. That conflicts with live GitHub and cannot reconstruct the reviewed head.

Root `AGENTS.md` requires every substantial task record to carry in-scope/out-of-scope, dependencies, acceptance, verification/checks, open-source survey/reuse decision, branch/commit/PR, status, implementation/evidence, blockers/risks, next action, and timestamps. The task has no explicit durable in-scope/out-of-scope section and does not link the final exact-head implementation/CI state back to the survey and verification evidence with the completeness required for this gate.

**Repair acceptance**

Execution must update the product-branch governance records, without weakening any production gate, so the task/WBS/risk/dependency/status/changelog/acceptance evidence truthfully reconstructs the complete final implementation chain through the actual final head, its applicable exact-head check/run IDs/results, scope/forbidden surface, dependencies, verification method, open-source survey linkage, remaining downstream post-merge gates, and timestamps. Any product head movement invalidates this exact-head review and requires a new independent review.

## OTHER-BLOCKING-1 — protected-enqueue product-gate contract is unsatisfied and internally contradictory

**Files / locations**

- `.github/workflows/automerge.yml` — `messagingPathPrefixes`, `requiredWorkflowsForPull`, `hasSuccessfulWorkflow`, and missing-workflow return path.
- `.github/workflows/messaging-product-gate.yml` — entire workflow trigger/job definition.

**Fact**

At exact reviewed source, `automerge.yml` treats `third_party/mahayana/mahayana-rs/mahayana-feature-host/` as a messaging path and therefore requires `Messaging Product Gate` in addition to `CI` (and Electron for the Electron paths). It authorizes enqueue only after a successful workflow run of every required workflow exists for the same head SHA.

PR #2561 changes `third_party/mahayana/mahayana-rs/mahayana-feature-host/**`, so this requirement applies. But `messaging-product-gate.yml` is currently `workflow_dispatch`-only with a single paused no-op job that states automatic messaging gate is paused. The exact-head workflow-run set for `3565c9d4...` contains no `Messaging Product Gate`. The successful `Explicit automerge` evaluator run is not evidence that the required product gate passed: its implementation returns successfully when required workflows are missing, so the evaluator workflow itself can be green while enqueue remains unauthorized.

Other green workflows, skipped/neutral jobs, an older-head run, a sibling run, or a manually dispatched paused placeholder cannot substitute for the repository-declared same-head product gate. This review did not dispatch or rerun anything.

**Repair acceptance**

The repository must restore a coherent protected-enqueue contract through the normal governed workflow: either a real `Messaging Product Gate` must naturally run for the final exact head and complete successfully with meaningful coverage, or the enqueue requirement/workflow topology must be corrected by a separately reviewed and protected governance change that preserves equivalent coverage. No manual placeholder run, skipped/neutral result, older-head evidence, or synthetic substitution is acceptable. Any resulting product/base/spec movement requires fresh exact-head review.

## Final disposition

`REVIEW-BLOCKED` for PR #2561 exact head `3565c9d483cb29e7729e3003e2b844b46124e18f` over exact base `9785d8e1b71e0d61cf31541af28b910d5be58bd9`.

- P0: 0
- P1: 1
- P2: 0
- other blocking: 1

This record grants **no** authorization to mark the product PR ready, enter/enqueue protected merge, merge, release, dispatch, or reuse prior production evidence. The only next stage is to return the two blockers to the execution/governance owners; after they are repaired and the final product head/base/spec are stable, a new genuinely independent exact-head review is required.