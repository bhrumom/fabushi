# FCM-010.13.11 exact-head independent review — PR #2558

- Repository: `bhrumom/fabushi`
- Product PR: `#2558`
- Atomic task ID: `FCM-010.13.11`
- Current repair task record: `management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md`
- Exact reviewed base: `a504f50ef6c8520517e91157bcc5769527d6e30a`
- Exact reviewed head: `9aee5e73fe053ca57a29fab08ad934eb200fade5`
- Review date: `2026-09-12`
- Review disposition: **REVIEW-PASS**
- Blocking findings: **none** (`P0=0`, `P1=0`, `P2=0`, other blocking findings `=0`)

This is a records-only independent review artifact. It does not modify or authorize modification of PR #2558's product head, does not mark the product PR ready, does not merge, release, or claim production acceptance. It authorizes only the next protected-merge stage while PR #2558 remains draft; all post-merge immutable-Release and fresh production acceptance gates remain mandatory.

## Exact specification binding

`spec_digest` is SHA-256 over the following UTF-8 manifest, sorted lexicographically by path, serialized as `<path>\t<git_blob_sha>\n` for each entry. Git blob SHAs were re-read from GitHub at exact head `9aee5e73fe053ca57a29fab08ad934eb200fade5`.

```text
projects/fabushi-cicd-merge-governance/SOURCE_OF_TRUTH.md	a0f02dc787d9005e4b2ea781766243a962ab6872
projects/fabushi-cicd-merge-governance/docs/02-需求与成功指标.md	98b9fbbe00bdeafd87a3b767eb730405213a1bae
projects/fabushi-cicd-merge-governance/docs/19-完成定义与验收.md	16255a2e702da2a8b04519aa46f0425da5e861af
projects/fabushi-cicd-merge-governance/management/01-WBS原子任务.md	1f932df51df0d434d34d025ab59f848ee523d10e
projects/fabushi-cicd-merge-governance/management/03-验收追踪矩阵.md	fad9e0d4384bd960015bd8b66692f3c07f0ee6b2
projects/fabushi-cicd-merge-governance/management/04-风险登记.md	550ca1cffed52b77f028b1ca28a4a9df9d5a507b
projects/fabushi-cicd-merge-governance/management/05-状态报告.md	9d1e21fa81f3016f4e80393c68cb5c1d30701637
projects/fabushi-cicd-merge-governance/management/06-依赖与阻塞.md	afb1a0d5a99aea3afa2af7782908b404e4ed198d
projects/fabushi-cicd-merge-governance/management/07-变更日志.md	9d238fca52b459410090a6302e1b22c3acbb0086
projects/fabushi-cicd-merge-governance/management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md	4d6481c1e6d5b68de6c195e22975a9aa943b0df6
```

- `spec_digest = a00d0c6f6ea9fa93cec5beaafd0feae366f51c879d3416f90c0c487f96ef52c8`

`review_key` follows the requested formula exactly:

`SHA256(repository + pr_number + exact_head_sha + exact_base_sha + atomic_task_id + spec_digest)`

with the UTF-8 concatenation inputs:

- repository: `bhrumom/fabushi`
- pr_number: `2558`
- exact_head_sha: `9aee5e73fe053ca57a29fab08ad934eb200fade5`
- exact_base_sha: `a504f50ef6c8520517e91157bcc5769527d6e30a`
- atomic_task_id: `FCM-010.13.11`
- spec_digest: `a00d0c6f6ea9fa93cec5beaafd0feae366f51c879d3416f90c0c487f96ef52c8`

- `review_key = f4e4200830793eed6177fd1e66bc59bec8edd9af0f63e7de6286dee76f4cdb33`

Any change to the product PR base/head or any bound specification blob invalidates this review.

## GitHub truth re-read

At review time GitHub showed PR #2558 `open` and `draft`, exact base `a504f50ef6c8520517e91157bcc5769527d6e30a`, exact head `9aee5e73fe053ca57a29fab08ad934eb200fade5`; canonical `main` was still exactly the same base SHA. The PR changed only the production journey, its deterministic controller contract, the packaged App Surface E2E, and FCM governance/task records. No workflow, dependency, product version, release version, or unrelated product path is changed by #2558.

The previous Codex review is historical and bound to rejected head `c9ee0c88ced2e51f774c89ffc37063967bd498c3`; it is not counted as a review pass for this head. A later Codex request for `9aee...` returned usage-limit messages and likewise is not review evidence. The old unresolved inline P1 thread concerns the stale risk/blocker wording on the older head; the exact reviewed head contains the corrected current truth and this review independently re-validated it.

## Exact-head CI readback

The following existing PR-side runs were re-read only; none was rerun:

- Required CI `34693419767`: success on exact head `9aee5e73...`; aggregate `CI result` success.
- FCM-010.13.11 controller contract `34693419723`: `External controller contract` actually executed and succeeded; production preflight/dispatch jobs were correctly skipped on PR.
- Electron desktop quality `34693419748`: success on exact head; the real Linux Rust Host pre-package simulated-user journey actually executed and succeeded before package/post-main-only work was skipped.

A separate Chrome Extension Web Store run `34693419739` has a failing `validate-package` job due to the untouched packaged Chrome journey timing out at 45 seconds after its preflight and 16 extension contract tests had succeeded. PR #2558 changes no Chrome path, that check is not a required FCM-010.13.11 exact-head gate, and it is therefore recorded as a truthful non-blocking adjacent failure rather than hidden or treated as evidence for this task.

## Code and semantic review

### 1. Production assistant-active -> non-assistant -> Chats precondition

The production journey deliberately leaves the legacy assistant active after conversation setup. At the start of `send`, the reviewed head now executes:

1. navigate to `频道`;
2. open the known already-created non-assistant `channelAId`;
3. navigate back to `聊天`;
4. record the list-state transition;
5. poll exact `peer-unread:legacy:conversation:mahayana-ai:agent:assistant` with exact name `unread-none`, `limit:1`, bounded 30-second wait;
6. only after that baseline is present, reopen the exact assistant and send.

This no longer relies on the invalid state where the assistant remains the active peer while probing a list-only unread avatar semantic node.

### 2. Deterministic controller contract

The exact-head controller contract locks the same ordering and exact semantic identity. It requires assistant active before `send`, then Channels -> `openPeer(channelAId)` -> Chats -> exact `waitForAssistantUnread(false, 30_000)` -> reopen exact assistant -> send. The contract retains exact assistant/unread IDs and names, legal find limits, a bounded timeout, and fail-closed uniqueness checks; no broad selector, fallback identity, success-on-timeout, or weakened ordering was introduced.

### 3. Packaged App Surface regression realism

The packaged Electron App Surface E2E deliberately establishes assistant-active state, proves that Chats-only navigation leaves exact `unread-none` absent, then selects `FCM semantic projection A` in Channels. It verifies durable projection state moved away from the assistant to a `selfhosted:` `activePeerKey`, returns to Chats, verifies that durable non-assistant key is retained, waits for the exact assistant unread semantic node to remount with exact ID/name/role, and immediately re-finds the stable assistant before invoke so the reopen uses the current generation/ref rather than a stale pre-poll generation. The current Electron Linux quality run exercised this regression successfully.

### 4. find bounds, retry/re-find, privacy and exact identity

Every reviewed production `fabushi.app.find` call remains at `limit<=100` (`1`, `2`, `5`, `10`, or `100` in the reviewed surrounding runtime); no `limit:200` remains. Generation-sensitive actions remain bounded and fail-closed: the shared helper keeps `DEFAULT_MAX_ATTEMPTS=32`, retries only `stale_app_surface_generation`, re-resolves the semantic query or stable agent on each retry, requires a unique current target and valid positive generation, and throws when rebase cannot be established. Query-side privacy semantics are preserved: server-side text/name matching remains authoritative because returned production fields are intentionally redacted, while stable `agentId`/role and uniqueness are rechecked. No relaxation of exact assistant or unread semantic identity was found.

### 5. Post-merge source/device/evidence gates remain downstream and strict

The reviewed change does not modify release workflows or evidence compilation. The production journey still enumerates exactly 27 required categories and throws if any is missing before success can be written. Only after all 27 categories are complete does it expose exact `settings-logout`, write `READY_FOR_LOGOUT PASS`, call `ci_session_finish`, take a fresh App snapshot, require exact `settings-logout` in that fresh generation, then invoke exact logout using that generation. Task/WBS/risk/dependency/status/changelog records continue to require a new canonical SHA, immutable same-source Release, fresh controller-dispatched frozen-source target, exact App-owned device, non-zero real remote actions, controller/target/truthful evidence success, playable whole-session video, trace, screenshots, logs, artifact digest, and source lineage. No old run/artifact is promoted to final acceptance and no PASS is written early.

### 6. Project truth reconstruction

The governance records distinguish closed historical blockers from the current state:

- protected-account/device HTTP-400/connectivity is closed historical; latest canonical target reached exact App-owned device and made 26 real remote actions;
- exact assistant projection is closed;
- playable whole-session recorder is closed;
- `fabushi.app.find limit>100` is closed/guarded;
- current runtime blocker is the assistant-active -> known non-assistant -> Chats -> exact unread list-state transition being repaired by #2558;
- current governance blocker remains exact-head independent no-finding review followed by protected queue ownership.

`FCM-010.13.11` and parent `FCM-010.13` remain `in-progress / fail-closed`; neither is prematurely closed. No stale current blocker was found in WBS/risk/status/dependencies/changelog/task after re-reading the exact head.

### 7. Scope, failure handling, race safety, recoverability and evidence truth

The changed runtime is narrowly scoped to establishing the missing real list-state precondition. It reuses an already-created known channel instead of inventing a new fallback identity. Polling and semantic uniqueness remain bounded/fail-closed. The packaged regression covers both the original assistant-active failure mode and the stale-generation failure found on the prior repair head. Failure handling still records failure and finishes the CI session without emitting the accepted READY/logout success chain. No P0/P1/P2 or other blocking issue was found in scope/allowlist, error handling, concurrency/generation race handling, recoverability, test realism, or governance record truth.

## Review conclusion and authorization boundary

**REVIEW-PASS exact head `9aee5e73fe053ca57a29fab08ad934eb200fade5`.**

- Exact base: `a504f50ef6c8520517e91157bcc5769527d6e30a`
- Task: `FCM-010.13.11`
- `spec_digest`: `a00d0c6f6ea9fa93cec5beaafd0feae366f51c879d3416f90c0c487f96ef52c8`
- `review_key`: `f4e4200830793eed6177fd1e66bc59bec8edd9af0f63e7de6286dee76f4cdb33`
- P0/P1/P2/blocking findings: none

This pass authorizes only the next protected merge stage for exactly the reviewed immutable inputs. It is not proof that #2558 is merged and is not production acceptance of FCM-010.13.11 / FCM-010.13. PR #2558 must remain draft until the external orchestration explicitly advances the protected merge flow, and any product-head/base/spec input change invalidates this review. Final task acceptance still requires the brand-new post-merge same-source production run and complete evidence chain described above.
