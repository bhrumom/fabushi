# FCM-010.13.11 independent exact-head review — PR #2561 — BLOCKED

- Project: `FAB-P0003 / FCM`
- Atomic task: `FCM-010.13.11-unread-deselect-governance-repair`
- Product PR: `#2561` (`fix(fcm): restore production assistant unread transition`)
- Review mode: independent, records-only; no product/test/workflow/dependency/version mutation; no ready/merge/release/dispatch; no PR-side CI rerun
- Expected product head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Expected PR review base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- Verdict: `REVIEW-FAIL / BLOCKED`
- Findings: `P0=0`, `P1=1`, `P2=0`, `other blocking=0`
- `spec_digest`: N/A — a digest/review key is intentionally not issued for a blocked review
- `review_key`: N/A — blocked review

## Immutable binding and two live reads

### Live read 1 — review start

GitHub PR state was read from the live PR object before substantive review:

- head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- state: `open`
- draft: `true`
- merged: `false`
- changed files: `13`
- commits: `17`

Both head and PR review base matched the expected immutable inputs.

For context only, the protected `main` branch had advanced to `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`; the live PR object nevertheless still reported the exact review base above. This review is bound to the PR object's exact head/base pair, not to an inferred current-main base.

### Live read 2 — immediately before verdict

The live PR object was read again after code, tests, records, checks, reviews/comments/threads, and OSS provenance inspection:

- head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- state: `open`
- draft: `true`
- merged: `false`

No head/base/status drift occurred between the two required reads.

## Diff and commit-chain review

The exact PR diff changes 13 paths: the Electron unread projection regression, Electron transport, the unread OSS survey, WBS/risk/blocker/task records, Mahayana lockfile, feature-host manifest/implementation, host manifest/implementation, and kernel conversation runtime.

The 17-commit product chain read from GitHub is:

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

The PR comparison is divergent from original branch point `b8fb73466899adc912db67823a8e429987070a6b`; the expected review base contains two base-only commits. Those base-only changes concern Chrome delivery/workflows plus the fresh FCM production-failure evidence and do not overlap the Rust/Electron repair implementation paths in a way that creates a new semantic conflict. GitHub reports the PR mergeable, but this review does not authorize merge.

## Independent implementation assessment

### Unread/read boundary

`KernelConversationProvider` now owns unread truth in `ConversationState`, with a per-conversation `read_through_by_conversation` boundary. Unread counts only assistant messages after the boundary, so user messages do not increment unread. `mark_read` counts only the named conversation, preventing an unrelated shared-provider conversation from clearing the assistant badge. The exact production-open adapter requests history with `limit=200`, while Runtime clamps larger background history requests to at most `500`; the provider marks read only for the explicit-open `200` contract. The cross-layer production regression explicitly proves that opening `codex:agent:research` does not clear Mahayana assistant unread, a background request of `2_000` is clamped and does not clear it, and explicit assistant open does.

The `200` numeric distinction is a scoped compatibility shim rather than a reusable read-receipt API. For this atomic task, its production caller and background caller are both locked by tests and the limitation is documented in the OSS-first record; no second conflicting `200` background caller was established in the reviewed paths. A future second consumer/provider/thread model must replace the shim with explicit read intent before reuse.

### Hidden completion

`SendMessageRequest.hidden` is propagated into the runtime kernel event bridge. Hidden `MessageCompleted` still emits the runtime completion event needed by background paths, but `record_assistant_completion(..., hidden=true)` does not append to visible conversation history, persist transcript content, or increment unread. Visible completions remain stored/persisted and increment unread. The production-adapter regression also verifies that hidden send leaves both unread and visible-history length unchanged.

### Persistence/session initialization

Persisted transcript loading initializes every existing conversation's boundary to its current visible-message count, so historical persisted messages start read, exactly matching this task's stated contract. New visible assistant completions become unread afterward. Session reset clears both visible history and all per-conversation boundaries and persists the cleared state. Read boundaries themselves are intentionally not separately persisted; restart semantics are therefore "persisted history starts read", not "preserve pre-restart unread".

### Concurrency / deadlock / race

The new conversation-state mutex is used for short synchronous state mutations/snapshots and is not held across backend `.await` execution. History read and read-boundary advancement are serialized under the same mutex; completion-vs-open ordering therefore has deterministic lock-order semantics: a completion serialized before the user's open is included in the read boundary, while one serialized after open remains unread. No new lock cycle or lock-across-await path was found in the changed code.

The existing persistence helper snapshots state and writes via a unique temporary file after releasing the state mutex; concurrent persistence can theoretically complete out of snapshot order, but that write-order behavior predates this PR and was not introduced by the unread repair. It is not counted as a blocking finding for this atomic change.

### Electron authoritative `conversation.list` refresh

The Electron transport now issues an authoritative `conversation.list` refresh after a successful non-Mini-App `conversation.open` and after a mapped assistant `chat.message`. Rust updates unread/read state before those projection refresh points, so the refreshed list reads runtime truth. The transport regression drives the actual command observer and runtime event path and requires both refresh request classes.

### Regression coverage

Exact-head CI includes the Rust provider unit regressions, the production FeatureHost adapter regression using a deterministic engine backend, transport command-event regression, direct Host/FeatureHost tests, renderer typecheck/build, and real Linux Rust-Host simulated-user path. The cross-layer adapter regression covers visible completion -> positive unread, unrelated open isolation, background history isolation, hidden completion isolation, and explicit assistant open -> zero unread.

No blocking product-code correctness defect was established in this independent review for unread/read-boundary, hidden completion, session initialization, locking, authoritative refresh, or the added regressions.

## Exact-head CI facts

For product head `3565c9d483cb29e7729e3003e2b844b46124e18f`, the live Actions/check read showed all naturally triggered workflows completed successfully; no failed or cancelled check run was present in the 32 exact-head check runs inspected. This review did not rerun any already-passing PR-side CI.

Key exact-head successful workflow runs include:

- `34704136567` — Mahayana fast checks; job `103581015078`, including formatting, CLI-first logic tests, direct Host, deterministic Feature Host, and production feature adapters.
- `34704136558` — Host fast E2E; job `103581002482`, including strict typecheck/build and complete Host user journey.
- `34704136680` — Electron desktop quality gate; Linux job `103581056066` plus result job `103581690895`, including architecture/bridge contracts, renderer TypeScript, native Host build, and real Linux Rust-Host simulated-user path.
- `34704136617` — Delivery governance contract.
- `34704136588` — CI.
- `34704136704` — CI latency observability.
- `34704136679` — Native mobile quality gate.
- `34704136578` — GBF security closure.
- `34704136652` — Project portfolio governance.
- `34704136654` — Mahayana Vendor Isolation.
- `34704136512` — Platform Control Plane.
- `34704136645` — Fabushi self-hosted messaging.
- `34704136537` — Mahayana iOS test-driver contract.
- `34704136551` — Computer control security gate.
- `34704136681` — Global Dharma Rust.

Two later `Explicit automerge` observations also completed successfully; they are not treated as review authorization and this review performs no ready/merge action.

## OSS-first / provenance assessment

The PR contains `projects/fabushi-cicd-merge-governance/evidence/2026-09-12-fcm-010-13-11-unread-open-source-survey.md`. I independently checked the cited upstream repositories rather than accepting the author statement as authority:

- `matrix-org/matrix-rust-sdk` is a live Rust SDK repository and GitHub reports Apache-2.0 licensing.
- `signalapp/Signal-Desktop` is a live Electron/TypeScript messenger repository and GitHub reports AGPL-3.0 licensing.
- `mattermost/mattermost` is a live collaboration repository whose repository license metadata is non-single-SPDX/mixed; the survey correctly treats direct source reuse as unattractive.

The survey records architecture/data-model/testing/operations/security/maintenance/license/compatibility analysis and explicitly chooses conceptual adaptation while adding no foreign messaging dependency and copying no cited source. The reviewed diff is consistent with that provenance decision. No OSS/provenance blocker is found.

## Blocking finding

### P1 — durable task/status/changelog truth is stale and cannot reconstruct the exact reviewed head

This is an independently reproduced repository-governance defect at exact head `3565c9d483cb29e7729e3003e2b844b46124e18f`.

`AGENTS.md` requires every substantial task record to include, among other fields, explicit in-scope/out-of-scope, dependencies, verification method/checks, open-source survey/reuse decision, branch/commit/PR, status, implementation summary, evidence, blockers/risks, next action and timestamps. It also requires material scope/governance changes in `management/07-变更日志.md`, the round/result in `management/05-状态报告.md`, and actual commit/PR/review/CI/check/test evidence where applicable.

At the reviewed product tree:

1. `management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md` still says the "latest implementation commit before this record update" is `4e064e7cf7b2b89be1e20f50b55576bf8ddb79bc`, although the product head contains eight later commits through `3565c9d4...`, including explicit-open documentation, the command-event regression, OSS survey, hidden-completion repair, per-conversation boundary repair, cross-layer production-adapter regression, and lockfile synchronization.
2. The same task record still says the final exact head has not passed all required CI and that a new exact-head CI cycle is required, while the live exact-head workflow/check state inspected above is already green.
3. The task record does not provide the required explicit in-scope/out-of-scope field, dependency field, verification method/checks field, or a direct task-record linkage/decision field for the new unread OSS-first survey.
4. Associated WBS/dependency/risk records remain phrased around the earlier `2e65...` review failure or "repair/re-review pending" state rather than reconstructing the final `3565...` chain and current green exact-head checks.
5. `management/05-状态报告.md` and `management/07-变更日志.md` do not append a final round/result that records `3565...`, the completed exact-head CI run/check evidence, the subsequent per-conversation/cross-layer/lockfile commits, and the current independent-review gate.

As a result, the repository's required durable working context cannot accurately reconstruct the implementation lineage and exact-head CI truth for the very head this review is asked to authorize. Passing code checks do not cure this records defect because the repository explicitly makes current project records/evidence part of completion/review governance.

### Required repair boundary

Repair only project governance records in the product change stream; no product implementation/test/workflow/dependency/version change is required for this finding:

- update the atomic task record with the complete final commit chain through `3565c9d4...`, explicit in/out scope, dependencies, verification/check method and exact-head results, and direct OSS survey/reuse linkage;
- synchronize the affected WBS/dependency/risk truth to the final repair state;
- append the exact final implementation/CI/review round to `management/05-状态报告.md` and material changes to `management/07-变更日志.md`;
- preserve `IN_PROGRESS / FAIL_CLOSED` because protected merge and fresh post-main production acceptance have not occurred.

Any product-PR governance commit will move #2561's product head and therefore invalidates this exact-head review binding. The repaired new exact head must obtain its own natural required CI and a new genuinely independent exact-head review; this record does not authorize merge.

## Final verdict

`REVIEW-FAIL / BLOCKED` — `P0=0`, `P1=1`, `P2=0`, `other blocking=0`.

The product implementation itself is not blocked by a newly established code defect in this round. The single blocking P1 is the stale/incomplete durable governance truth required by repository policy. No `REVIEW-PASS`, `spec_digest`, or `review_key` is issued.
