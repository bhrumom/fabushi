# FCM-010.13.11 PR #2561 independent exact-head review — round 3

- Review project: `代码审查项目组`
- Repository: `bhrumom/fabushi`
- Project: `FAB-P0003 / FCM`
- Atomic task: `FCM-010.13.11-unread-deselect-governance-repair`
- Product PR: `#2561`
- Frozen review base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- Frozen product head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Product task record: `projects/fabushi-cicd-merge-governance/management/tasks/FCM-010.13.11-unread-deselect-governance-repair.md`
- Canonical `main` observed for integration context only: `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`
- Independently recomputed live spec digest: `391e7a3ee4bda068398ff166f45371391a877d728ebc16e4fe96802a4a310307`
- Review key: **not issued** because this round does not satisfy the repository/user PASS conditions.
- Verdict: **REVIEW-BLOCKED**
- Findings: `P0=0`, `P1=1`, `P2=0`, `other blocking=1`

## Independence and immutable binding

This is a new review round. Earlier REVIEW-PASS/REVIEW-BLOCKED records, Codex reviews, handoffs, comments, and reviewer records were treated only as search clues. The conclusion below was reconstructed from the current GitHub PR, the exact frozen product head/base, repository files at that exact head, current Actions/check state, current protected-merge workflow definitions, and current canonical `main` integration context.

The initial live read confirmed PR #2561 remained open, unmerged, and draft, with exact head `3565c9d483cb29e7729e3003e2b844b46124e18f` and exact base `9785d8e1b71e0d61cf31541af28b910d5be58bd9`. Current canonical `main` was `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`; that newer SHA was not substituted for the frozen review base.

The spec digest was recomputed from the live exact-head authoritative FAB-P0003 manifest inputs rather than copied from a prior reviewer record. The manifest covers SOURCE_OF_TRUTH, stable requirements/DoD, WBS, acceptance, risk, status, dependency/blocker, changelog, and the atomic task record. The resulting digest is `391e7a3ee4bda068398ff166f45371391a877d728ebc16e4fe96802a4a310307`.

## Independent product/semantic review

The 13-file PR stays within the atomic repair and its durable project/test-support evidence surface. It does not modify `.github/workflows/**`, release/version metadata, or unrelated product domains. The product changes are concentrated in Electron Mahayana transport, Mahayana FeatureHost/Host/Runtime, the workspace lockfile/test-support relationships, deterministic regressions, and FCM project evidence/records.

The runtime repair keeps unread truth in `KernelConversationProvider`, not the renderer. `ConversationState` tracks `read_through_by_conversation` keyed by conversation identity, initializes persisted history as already read, counts only visible assistant completions after that conversation's read boundary, does not count user messages, does not count hidden assistant completions, marks only the explicitly opened conversation read, and clears history/read boundaries together on reset. This removes the prior shared-provider cross-conversation acknowledgement defect: an explicit open of `codex:agent:research` cannot acknowledge `mahayana-ai:agent:assistant`.

The existing FeatureHost contract separation is preserved: explicit production `conversation.open` requests history limit `200`, while the background index path requests `2000` and Runtime clamps it to `500`; the provider acknowledges read only for the exact `200` explicit-open contract. Background/index history therefore remains observational. The repository's open-source survey explicitly documents this as a narrow compatibility shim, records the condition requiring a future explicit read API if the numeric contract is reused/expanded, and records Matrix/Signal/Mattermost architecture, license, security, maintenance, compatibility, and reuse/reject decisions. No surveyed source is copied and no new broad messaging dependency is introduced.

Electron transport requests a fresh authoritative `conversation.list` after a non-Mini-App conversation open and after an assistant `chat.message`. The refresh is list-only and cannot advance the runtime read boundary. The exact semantic assistant identity/name remains canonical; the PR does not introduce screenshot/OCR/private-message inference. A refresh failure is logged while runtime state remains authoritative, so the new code does not corrupt read state on the error path.

The deterministic Rust regression is not a fixture-only self-proof: it drives the production FeatureHost conversation adapter over MahayanaHost -> Runtime clamp -> KernelConversationProvider with a deterministic kernel backend. It covers initial/read state, visible assistant completion -> positive unread, unrelated shared-provider explicit open not clearing assistant unread, background `2000 -> 500` history not clearing unread, hidden completion not entering visible history/unread, and explicit assistant open -> unread zero. The Electron regression independently covers the two authoritative list-refresh points. The Cargo/test-support changes are narrow workspace/test-only support needed for that real cross-layer regression; the lockfile sync does not introduce a new external package source/version or new licensing obligation.

No blocking race/deadlock/reentrancy regression was established in the changed path. The provider does not hold the changed synchronous state lock across backend async execution; read acknowledgement is scoped per conversation; list refresh is observational. Duplicate visible completion events would be distinct authoritative assistant completions under the backend event contract rather than renderer-manufactured unread state. Restart semantics deliberately treat persisted history as read, matching the recorded acceptance and open-source survey.

The PR also leaves the post-main FCM-010.13.11 acceptance intact: no source->Release->device constraint, exact App-owned device binding, 27-category requirement, nonzero real remote actions, READY_FOR_LOGOUT -> `ci_session_finish` -> fresh App snapshot -> exact settings-logout ordering, truthful evidence gate, playable video/trace/screenshots/logs, artifact digest, or source lineage requirement is weakened.

## Finding P1 — durable task/project record does not reconstruct this exact head

The exact-head atomic task card still states `4e064e7cf7b2b89be1e20f50b55576bf8ddb79bc` is the "Latest implementation commit before this record update" and still describes the eventual final exact-head CI as not yet passed. The actual reviewed product head is later: `3565c9d483cb29e7729e3003e2b844b46124e18f`, including later per-conversation isolation, hidden-completion coverage, the real cross-layer regression, and lockfile sync. Live exact-head Actions/checks have also advanced beyond the task card's recorded CI state. WBS/risk/dependency records likewise retain wording such as the cross-layer regression being added and CI/independent re-review pending.

This conflicts with the repository requirement that durable project records reconstruct the final implementation, verification, evidence, blocker, and next action from the repository itself. It is not safe to authorize merge while the authoritative task record describes an earlier implementation/CI state.

**Repair acceptance:** the task/project records must be synchronized to the actual final product head and exact-head Actions truth without weakening the acceptance criteria or post-main evidence chain. Any product-PR commit used to repair those records creates a new product head and therefore invalidates this review; that new immutable head must receive its own exact-head CI/review.

## Other blocking — protected-merge required messaging gate is not currently proven/satisfiable as genuine same-head evidence

The exact-head `.github/workflows/automerge.yml` classifies `third_party/mahayana/mahayana-rs/mahayana-feature-host/**` as a messaging-impact path. PR #2561 changes that path, so the evaluator requires a same-head successful workflow named `Messaging Product Gate`, in addition to base CI and Electron desktop quality. The exact product head has no workflow run named `Messaging Product Gate`.

The exact-head and current-main `.github/workflows/messaging-product-gate.yml` are both `workflow_dispatch`-only and contain a single `paused` job that only echoes `Automatic messaging gate paused for 2026-09-05 Mac test release.` This is not a real messaging product validation surface. A manually manufactured green placeholder cannot substitute for required same-head product evidence, and this review round does not dispatch it.

Several `Explicit automerge` runs on this exact head conclude `success`, but the workflow has legitimate early-return paths before enqueue, including the current PR's `draft` state and missing required workflows. Its success conclusion is therefore evaluator execution success, not proof that protected enqueue was authorized or that a merge-queue entry exists. This round does not treat those green checks as merge authorization.

**Repair acceptance:** repository governance must provide a genuine, non-placeholder messaging product gate that can naturally produce same-head validation for the impacted FeatureHost path (or separately change the authoritative required-gate contract through its own reviewed governance process). Only then may the unchanged/new exact product head present objective same-head required evidence to an independent reviewer. Do not substitute older-head, sibling, synthetic, skipped/neutral, or paused-placeholder success.

## Exact-head CI truth

At review time the exact product head had completed successful ordinary PR-side Actions/checks across the relevant base CI, Rust/Mahayana, Electron desktop, architecture/protocol/security surfaces; no exact-head failed check-run was found. In particular `CI result`, Rust protocol/Host/bridge fast gate, Mahayana tests, messaging-core checks, Electron Linux and aggregate `Electron desktop result` were successful. Skipped release/publish jobs are not being counted as required proof.

GitHub's legacy combined-status endpoint reported `pending` with `statuses=[]`; that endpoint has no traditional commit statuses for this SHA and is not used to contradict the actual Actions check-runs. The blocking CI/evidence fact is narrower: the required same-head `Messaging Product Gate` is absent, while its current workflow definition is paused/manual-only. Therefore the condition "all required same-head CI/evidence completed/successfully and protected-merge governance can naturally be satisfied" is not met.

## Authorization boundary and conclusion

`P0=0`, `P1=1`, `P2=0`, `other blocking=1`.

Final verdict for this independent round: **REVIEW-BLOCKED**.

This record does not authorize ready-for-review, merge queue entry, merge, Release, dispatch, CI rerun, or downstream production acceptance. It does not modify PR #2561's product head. No `review_key` is issued because the PASS preconditions are not met.

The sole next action is to return these two blockers to the architecture/execution owner for one fail-closed repair round: synchronize the durable FCM records to the final implementation/CI truth and restore a genuine naturally satisfiable messaging-gate path, then present the resulting unchanged exact product head/base/spec binding for a new independent review. Until that happens, #2561 must remain outside downstream merge/release/dispatch.
