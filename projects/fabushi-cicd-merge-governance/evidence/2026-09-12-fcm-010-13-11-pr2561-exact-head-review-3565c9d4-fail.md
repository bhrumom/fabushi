# FCM-010.13.11 PR #2561 exact-head independent review — REVIEW-FAIL

## Review identity

- Repository: `bhrumom/fabushi`
- Project: `FAB-P0003 / FCM`
- Atomic task ID: `FCM-010.13.11-unread-deselect-governance-repair`
- WBS parent ID: `FCM-010.13.11`
- Product PR: `#2561` — `fix(fcm): restore production assistant unread transition`
- Exact review base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- Exact product head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Product head changed by this review: **no**
- Review date: `2026-09-12 UTC`
- Result: **REVIEW-FAIL**
- Finding counts: `P0=0`, `P1=1`, `P2=0`, `other blocking=0`

This is a fresh independent review. Older REVIEW-PASS/FAIL records, Codex reviews, comments, handoffs, sibling PRs and earlier-head CI were used only as navigation clues and not as authorization or as the basis of this verdict.

## Exact-head / exact-base binding

Initial live read of PR #2561:

- state: `open`
- draft: `true`
- merged: `false`
- mergeable: `true`
- commits: `17`
- changed files: `13`
- base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- head: `3565c9d483cb29e7729e3003e2b844b46124e18f`

Final live read before verdict:

- state: `open`
- draft: `true`
- merged: `false`
- mergeable: `true`
- commits: `17`
- changed files: `13`
- base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- head: `3565c9d483cb29e7729e3003e2b844b46124e18f`

The expected head/base therefore stayed exact and unchanged throughout the review.

## Canonical spec digest

The repository's existing reviewer-record mechanism hashes a UTF-8 manifest sorted lexicographically by path, one line per canonical input in the form `<path>\t<git_blob_sha>\n`.

Exact-head manifest:

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

- `spec_digest = 29cb82869dca4fdaae3cce222364d5c685232937e287184fd7866e9f60791453`
- `review_key = SHA256(repository + pr_number + head_sha + base_sha + atomic_task_id + spec_digest)`
- `review_key = a0efb5c4475780de5fb577d44ad9e4516100466df5adc11e3364cbc18473413a`

For `review_key`, `atomic_task_id` is the canonical full task ID `FCM-010.13.11-unread-deselect-governance-repair` supplied by the task record/review target, not the shorter WBS parent ID.

## Exact-head CI / raw evidence

The final exact head has current GitHub Actions evidence; older/sibling/manual evidence was not substituted for it. All observed applicable workflow runs for `3565c9d483cb29e7729e3003e2b844b46124e18f` were `completed/success`, including:

- `Mahayana fast checks` run `34704136567` — success. The exact-head job explicitly completed `Test production feature adapters over the cached direct Host` successfully, in addition to direct Host/runtime/harness checks.
- `Electron desktop quality gate` run `34704136680` — success. The exact-head Electron job completed main-process contract tests, renderer TypeScript/build, real Linux Rust Host bootstrap, and `Simulate a user against the real Linux Rust Host before packaging`; its aggregate `Electron desktop result` also succeeded.
- `CI` run `34704136588` — success.
- `Host fast E2E` run `34704136558` — success.
- `Computer control security gate` run `34704136551` — success.
- `Mahayana iOS test-driver contract` run `34704136537` — success.
- `Delivery governance contract` run `34704136617` — success.
- `Project portfolio governance` run `34704136652` — success.
- `Mahayana Vendor Isolation` run `34704136654` — success.
- `Native mobile quality gate` run `34704136679` — success.
- `Platform Control Plane` run `34704136512` — success.

Main-only packaging/release steps skipped inside a PR event are not treated as required PR-side evidence and are not used to claim post-merge acceptance.

## Independent implementation / test review

### Production unread/read boundary

The current code implements a per-conversation `ConversationState` in `KernelConversationProvider` with a per-conversation read-through boundary. Persisted history starts at the read boundary; only later assistant completions count as unread; user messages do not increment unread. Hidden assistant completion is excluded from visible history/unread and does not get persisted as a visible completion.

The explicit-open compatibility contract is narrow and testable:

- FeatureHost production `conversation.open` requests `ConversationHistory(limit=200)`.
- `KernelConversationProvider` marks read only when the provider receives exactly `200`.
- FeatureHost's background history/index path requests `2,000`.
- Runtime clamps all history requests to `1..=500`, so that background `2,000` reaches the provider as `500`.
- `500` does not mark read.

Reset clears both history and all read-through boundaries. Mutex guards introduced by this repair are not held across an async `.await`; poison paths map to explicit provider/backend errors rather than silently succeeding.

The local persisted transcript encoding remains a message vector rather than a new incompatible state schema. On restart, loaded history is deliberately treated as already-read, which prevents historical assistant messages from becoming false new unread state. Rollback therefore does not require a transcript migration.

### Production adapter regression

The new Rust cross-layer test does not merely reimplement the condition in a mock. It constructs a real `MahayanaHost`, real Runtime, real provider registry / `KernelConversationProvider`, and the FeatureHost production adapter path; only the `EngineBackend` is replaced with a deterministic backend that emits a real kernel `MessageCompleted` event.

That regression proves:

- `0 -> 1` assistant unread transition through the real Runtime/provider path;
- opening an unrelated shared-provider conversation does not clear assistant unread;
- background `2,000 -> Runtime clamp 500` history leaves unread unchanged;
- hidden completion does not add visible history/unread;
- explicit assistant open through the production adapter clears unread to zero.

The `test-support` Host constructor is feature-gated and hidden, and the new Host/Kernel dependencies in the FeatureHost crate are dev-dependencies. The lockfile change adds those test dependency edges plus a package ordering move; it does not introduce a new third-party runtime package/version.

### Electron authoritative projection

The Electron transport now requests authoritative `conversation.list`:

- after a successfully accepted non-Mini-App `conversation.open`;
- after an assistant `chat.message` completion event.

Refresh failure is logged and does not falsify local projection state. The transport regression executes the real `ElectronMahayanaHostTransport` command/event logic and mocks only the outer Electron bridge boundary; it verifies two distinct authoritative list refresh calls, one after open and one after assistant completion.

### Existing fail-closed gates / security / compatibility

The product diff does not modify the established semantic identity/name, generation re-resolution, or `fabushi.app.find limit<=100` implementation surfaces. The task/PR contract continues to require them; no weakening of those gates was found in the changed files.

The public production `conversation.open` path retains authenticated-account enforcement. The test-only production-adapter helper is private and the injected Host constructor is feature-gated. No new credential, network authority, screenshot/OCR fallback, workflow permission, release bypass, or product storage format is introduced.

The open-source-first survey is present and materially covers Matrix Rust SDK, Signal Desktop and Mattermost across architecture/API/data model/testing/operations/security/maintenance/license/compatibility; it records learn/adapt/reject decisions and explicitly rejects dependency/source reuse that would create disproportionate protocol or license cost.

No independent code-level P0/P1/P2 defect was found in the final implementation/test delta reviewed at this exact head.

## Blocking finding

### P1 — canonical task/management truth is stale and incomplete relative to the final exact head

This is independently reproduced from the current exact-head repository state, not inherited from an older review.

The canonical task record `management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md` at the final head still states:

- `Latest implementation commit before this record update: 4e064e7cf7b2b89be1e20f50b55576bf8ddb79bc`;
- the final exact head has not passed all required CI / replacement CI is still pending.

Those statements are false for the live review target: the PR has 17 commits through `3565c9d483cb29e7729e3003e2b844b46124e18f`, including later hidden-completion, per-conversation, cross-layer production-adapter and lockfile commits, and the final exact-head applicable workflows are completed/success.

The broader durable records are likewise not reconstructed to the final state. The WBS still describes repair commit `25f95c1f...` plus a production-adapter regression “being added” and says new exact-head CI/re-review remain; the risk/dependency records likewise describe the cross-layer regression/CI as pending rather than binding the final 17-commit head and its completed runs. The status/changelog entries remain centered on an earlier list-state repair round rather than this final runtime-unread exact-head evidence.

In addition, the canonical task record does not itself provide the repository-required explicit durable task fields for in-scope/out-of-scope, dependencies, verification method/checks, and linkage to the open-source survey/reuse decision. The survey file exists and is good evidence, but the durable task record is not self-sufficient/reconstructable as required by root `AGENTS.md`.

This directly violates the current Source of Truth requirement that project governance state match real GitHub evidence, the repository task-record quality gate, and this review's explicit requirement that task/requirement/acceptance/spec digest, implementation, tests and records agree. A green exact-head CI set cannot substitute for incorrect durable task truth.

### Required repair

Update the canonical product-side task/WBS/risk/dependency/status/changelog truth so it reconstructs the final implementation commit chain and exact-head CI evidence and contains/links all mandatory task fields. Because that changes PR #2561's product head, the repaired new head must receive a wholly new exact-head review; this records-only review cannot repair the product head and cannot be upgraded in place to a PASS.

## Verdict / authorization boundary

**REVIEW-FAIL — P0=0, P1=1, P2=0, other blocking=0.**

No `REVIEW-PASS` is issued. This record does not authorize ready-for-review, merge, merge queue entry, release, production dispatch, or reuse of any prior production target/evidence. Product PR #2561 must remain fail-closed until the P1 durable-record inconsistency is repaired on a new product head and that new exact head passes fresh independent review.
