# FCM-010.13.11 fresh independent exact-head review — PR #2561 — BLOCKED

- Review date: 2026-09-13
- Reviewer round: fresh independent code-review session; historical REVIEW-PASS/REVIEW-FAIL records, PR #2569's pre-existing verdict text, prior handoffs, and prior Codex conclusions were not used as authority for this verdict.
- Repository: `bhrumom/fabushi`
- Project: `FAB-P0003 / FCM`
- Atomic task: `FCM-010.13.11-unread-deselect-governance-repair`
- Product PR: `#2561`
- Exact review base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- Exact product head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Product state at initial freeze and second pre-verdict freeze: `open`, `draft=true`, `merged=false`
- Verdict: **REVIEW-FAIL / BLOCKED**
- Findings: **P0=0 / P1=1 / P2=0 / other blocking=0**

## Independent live-read scope

This round independently re-read from live GitHub rather than inheriting earlier review outcomes:

- PR #2561 current metadata, complete changed-file set, full patch, 17-commit chain, reviews, issue comments, inline review threads, and exact-head workflow/check evidence;
- root `AGENTS.md` and FAB-P0003 `SOURCE_OF_TRUTH.md`;
- the active task record, WBS, status report, changelog, risk register, dependency/blocker register, acceptance matrix, and the task's open-source-first survey;
- the current Rust runtime provider, FeatureHost production adapter/regression, Host test-support boundary, Cargo manifests/lockfile delta, and Electron transport/E2E regression.

The second pre-verdict live read again returned base `9785d8e1b71e0d61cf31541af28b910d5be58bd9` and head `3565c9d483cb29e7729e3003e2b844b46124e18f`; no exact-head drift occurred during review.

## Final product commit chain reviewed

1. `ee72976028a856ea1b7e10345b9fa1f0f2bc6c7a` — `fix(fcm): track assistant unread state in kernel provider`
2. `874b2bbe98c01a4e35394b3cd8a319489baa00a5` — `fix(fcm): refresh unread projection after assistant events`
3. `e37adb95513e50219de0feb683dcd0e61fff8da1` — `test(fcm): lock authoritative unread projection refresh`
4. `1cb9646aa2bc698e401a11478721a0df98b9aab9` — `docs(fcm): record fresh unread production failure`
5. `9249929d12f07a93b809d1044c386dc72d34ef04` — `docs(fcm): correct exact-head review lineage`
6. `5b8df01c3dde8c911fbdb87a131152980ce5f726` — `docs(fcm): sync WBS to fresh unread blocker`
7. `d7628fdec9de889c193d29ad9f0346ecfa4ac934` — `docs(fcm): move blocker to runtime unread projection`
8. `81a0602cfa79450c2a92b94fd01c4cc13617a0bd` — `docs(fcm): track runtime unread production risk`
9. `4e064e7cf7b2b89be1e20f50b55576bf8ddb79bc` — `fix(fcm): keep background history scans from clearing unread`
10. `56f3f7cee2048c994613be7f33c771041c3174f3` — `docs(fcm): lock explicit-open unread read boundary`
11. `3809867c5f03151caf149af893c910affe962201` — `test(fcm): drive transport command events in unread regression`
12. `273ae8d986a277bd5313cb6567db95c99515fbd7` — `docs(fcm): record unread open-source-first survey`
13. `d51bcff37434e8a6b698b3e1e78f3e05fd912ed5` — `fix(fcm): exclude hidden completions from unread state`
14. `2e65a0a6de736d11774895938989232b376c6ed6` — `style(fcm): format hidden unread regression`
15. `25f95c1f69edc7819b03ceb55e78b245a827f380` — `fix(fcm): scope unread boundary per conversation`
16. `470d7f4bbe9cfc12c7564e60744d427cc4c37e38` — `test(fcm): cover conversation-scoped unread adapter`
17. `3565c9d483cb29e7729e3003e2b844b46124e18f` — `chore(fcm): sync mahayana lockfile for unread regression`

## Product-code review disposition

No independent P0/P1/P2 product-code defect was found in the final exact-head behavior reviewed here.

### Unread/read-boundary and per-conversation state

`KernelConversationProvider` now owns `ConversationState` with visible history plus a `read_through_by_conversation` boundary. Unread is computed for the requested conversation only, after that conversation's read boundary, and counts only assistant-role messages. Opening one conversation therefore does not clear another conversation's unread state.

### User messages, hidden completions, persisted history, reset

- Visible user messages may be persisted but do not increment assistant unread because unread counts assistant-role messages only.
- Hidden assistant completions are not inserted into visible history/unread state.
- Persisted history initializes each conversation's read boundary to its current visible-message count, so restarting does not manufacture historical unread.
- Session reset clears both visible history and read-boundary state before the empty history is persisted.

### Explicit open versus background history

The current compatibility boundary is explicit and regression-locked: production open requests `history(..., 200)`, while FeatureHost background indexing requests `2_000` and Runtime clamps it to `500`. The provider marks read only for the exact explicit-open `200` contract. The final tests prove `500` background retrieval cannot clear unread and that opening an unrelated conversation does not clear assistant unread.

This numeric intent encoding is a deliberately documented compatibility shim, not a general protocol. The open-source survey correctly records the follow-up condition that a future second `200` background caller, multi-provider reuse, or thread model must replace it with an explicit read-boundary API.

### Concurrency / mutex / await / deadlock review

The new synchronous conversation-state mutex is used for short in-memory state operations and snapshots. Relevant async backend/filesystem awaits occur after releasing that state lock. Session initialization serializes the session-id transition with the existing async mutex; the reviewed call graph does not introduce a new lock-order cycle or await while holding the synchronous conversation-state lock. No task-specific deadlock/race blocker was established in this delta.

### Electron authoritative refresh and cross-layer regression

Electron transport now requests authoritative `conversation.list` refresh after accepted non-Mini-App `conversation.open` and after assistant `chat.message` completion. The transport regression drives the real command-observer mapping and proves both refresh points.

The Rust FeatureHost regression is not merely a mocked list field: it creates the production Host/Runtime with a deterministic injected engine backend, sends through Runtime, reads through the production FeatureHost list/open helpers, and covers visible assistant unread, unrelated-open isolation, background-history isolation, hidden completion, and explicit-open clear. Host `test-support` is feature-gated and the added Cargo dependencies are test/dev support; the lockfile delta adds those workspace/dev edges without introducing a new third-party production dependency.

### Error handling / rollback

The Electron list refresh is best-effort and logs refresh failure rather than corrupting conversation state. Runtime/provider mutations remain authoritative, so a renderer refresh failure can leave a temporarily stale projection but does not falsify the underlying unread count. This round found no acceptance-level rollback/error-handling blocker in the reviewed atomic change.

### OSS-first / provenance / license

The exact-head survey evaluates Matrix Rust SDK, Signal Desktop, and Mattermost across architecture, data model, testing, operations, privacy/security, maintenance, compatibility, and licensing. It records architectural learning only: Matrix's explicit read-state/event-derived approach is adapted conceptually; Signal's AGPL implementation and Mattermost's mixed/AGPL server source are not reused; no source from those projects is copied and no broad messaging dependency is added. The final custom compatibility shim and its architectural limit are explicitly documented.

## Exact-head CI evidence independently read

GitHub reports 32 check runs on `3565c9d483cb29e7729e3003e2b844b46124e18f`. Relevant PR-side gates are completed successfully, including:

- `CI result` — run `34704136588`, check `103581002621` — `success`;
- `Rust protocol, Host, and bridge fast gate` — run `34704136567`, check `103581015078` — `success`;
- `Electron desktop result` — run `34704136680`, check `103581690895` — `success`;
- `React Host complete user journey` — run `34704136558`, check `103581002482` — `success`;
- `mahayana-test` — run `34704136681`, check `103581002772` — `success`;
- native/security/project-governance checks observed on the same exact head are also completed successfully.

PR-only release/deploy jobs that are intentionally non-applicable remain skipped; no passed workflow was rerun by this review.

## P1 — durable project records do not reconstruct the final exact-head implementation/CI truth

**Severity: P1 / blocking.**

This finding was independently reproduced from the current repository state; it is not inherited from any historical review.

### Reproducible evidence

1. Live GitHub says the final product head is `3565c9d483cb29e7729e3003e2b844b46124e18f`, with 17 commits and successful exact-head PR-side CI.
2. The task record on that exact head still says PR #2561 is "awaiting exact-head CI/review", identifies `4e064e7c...` as the latest implementation commit before the record update, and states that a new exact-head CI cycle is required. It therefore omits the later explicit-open record, transport-event regression, OSS survey, hidden-completion fix, per-conversation fix, cross-layer regression, lockfile synchronization, and their final exact-head CI result.
3. The WBS/risk/dependency records likewise retain the earlier pending/re-review state rather than binding the current `3565...` chain and current green CI.
4. The current status report's latest FCM-010.13.11 section explicitly says status/changelog synchronization is required before review, but neither the status report nor the changelog contains the current runtime-unread implementation round / final exact head / final exact-head CI result.
5. The acceptance matrix still points the installed-App journey row at an older historical production failure and does not record the current repair-head review/CI truth.
6. Root `AGENTS.md` requires every substantial task to maintain a durable task record with branch/commit/PR, status, implementation summary, verification/checks, open-source decision, and actual CI/evidence, and requires affected WBS/status/changelog/risk/dependency/acceptance records to stay synchronized before claiming completion/review progression.

The product code can therefore be technically sound while the governed atomic task is still not truthfully reconstructible from its authoritative durable records. That is a merge-authorizing review blocker.

### Minimal repair boundary

Do **not** change the reviewed product behavior merely to satisfy this finding. On PR #2561, make only the minimum project-record synchronization needed to make repository truth self-consistent, including as applicable:

- active task record: bind the complete final implementation lineage / final exact head and exact-head CI evidence; make scope/out-of-scope, dependencies, verification checks, OSS survey/reuse decision, status and implementation summary reconstructible;
- WBS: replace old-head/pending-CI wording with the actual current repair state;
- append-only status report and changelog: record the runtime-unread repair round and exact-head CI truth rather than leaving the project's own "required before review" synchronization unmet;
- affected risk and dependency/blocker entries: distinguish closed implementation risks from the still-open independent-review/protected-merge/post-main gates;
- acceptance matrix: remove obsolete current-blocker semantics and point the pre-merge acceptance state at the actual current repair head while preserving the still-pending post-merge production journey.

Any such product-branch record synchronization changes PR #2561's head. Therefore this review is invalid for that new head and a **new independent exact-head review is mandatory**. This record does not authorize amending the current review to PASS after the fact.

## Terminal disposition

**REVIEW-FAIL / BLOCKED**

- P0: `0`
- P1: `1`
- P2: `0`
- other blocking: `0`

No `REVIEW-PASS` is issued. No ready/merge/release/dispatch/CI-rerun/downstream authorization is granted. PR #2561 must remain fail-closed until the records-only product-governance repair creates a new exact product head, its natural required CI completes, and a fresh independent reviewer binds to that new exact head/base and finds zero blocking issues.
