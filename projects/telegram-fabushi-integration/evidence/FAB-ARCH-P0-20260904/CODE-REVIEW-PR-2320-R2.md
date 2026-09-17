# CODE REVIEW — PR #2320 — R2 independent re-review

- Project: `FAB-P0001 / TFI`
- Program: `FAB-ARCH-P0-20260904`
- Review round: `R2`
- Verdict: **REVIEW-REJECTED**
- Reviewed PR: `#2320`
- Reviewed base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed head: `arch/p0-recovery-20260904@a5ce2e522cf124910c6627c72a646513b90960fa`
- Review time: `2026-09-04 +08:00`
- Write-back branch: `review/pr-2320-r2-20260904-a5ce2e5`
- Write-back PR: `#2321`
- Initial evidence commit: `2fb3d8600dfaf905257e3aa4c0b5caef14ca0921`
- Review PR creation head: `90ced0c111435a3fb4661d533a82beab30c44816`
- Local build/test: **not run** (prohibited for this governance review)

## Independent review basis

This is a fresh real-diff review of head `a5ce2e5...`; it does not reuse the prior verdict as proof. The previous `REVIEW-REJECTED` record for the earlier head remains historical evidence and is not amended.

Reviewed against canonical `main@688465e...`: root `AGENTS.md`; `projects/PORTFOLIO.json`; `projects/PROJECT_ID_POLICY.md`; TFI/MSR/GBF `SOURCE_OF_TRUTH.md`, `README.md`, `PROJECT.yaml`, `OWNERS.md`; current P0 WBS/milestone/acceptance/risk/dependency/status/changelog records; all three prior code-review and architecture-repair records; and all 13 authoritative atomic task files.

The M6 factual audit also read `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d` directly in `native/mahayana-messaging/src/engine.rs` and `service.rs`.

## Findings that are now correct

1. PR #2320 is still open/unmerged and its 73 changed files are all under `projects/**`. It does not modify application source, `.github/workflows/**`, root `AGENTS.md`, `projects/PORTFOLIO.json`, or `projects/PROJECT_ID_POLICY.md`.
2. Project identity remains `FAB-P0001/TFI`, `FAB-P0005/MSR`, `FAB-P0004/GBF`; registry/policy blobs are unchanged from canonical main.
3. All 13 authoritative task files now contain stable identity, explicit implementation scope/interfaces, current dependency state, parallel conditions, implementation steps, in/out scope, six acceptance categories, and real branch/commit/PR/review/CI/evidence/status/changelog write-back rules. `planned/pending` is not treated as passed. MSR-107's governance-only N/A categories include reason, substitute check, and owner.
4. M6 facts are correctly represented: at `9e88a2e...`, missing-Community `RequestCommunityJoin` already returns `CommunityNotFound` and is correctly a regression gate; `RespondCommunityJoin` still contains the bool/optional-event compile defect; `CreateConversation` still projects directly to `UpsertConversation`; and the public/private/invite/join-request positive/negative admission matrix remains required.
5. Root `AGENTS.md` exact-main packaged evidence identity is carried into the task handoffs: canonical-main SHA, version, platform, workflow run/job, journey/test ID, timestamp, installable/package identity, complete video, step screenshots, trace, HTML/native report and logs; pass/fail evidence is always-equivalent uploaded with 90-day target or recorded lower platform limit.
6. MSR exact-file provenance is fixed: actual Codex/Grok Build adaptation must record upstream repository, exact file/revision, license, NOTICE/attribution disposition, local destination and adaptation/reimplementation decision at implementation time. Architecture pins are insufficient. Reconstructed Grok Bot is limited to observable clean-room behavior/UI/IPC evidence; no copy/translation/template use; unclear-rights items remain `UNMAPPED/EVIDENCE_ONLY`/do-not-use.
7. GBF-508's semantic-to-Computer-Use hard gate is complete: same-account pairing/control, current target/session/client/generation, true semantic unavailability rather than denial, approval granted/unexpired, MiniApp/install allowance, audited/correlated action, and fail-closed deny/expire/revoke/stale/available-but-denied semantics.

## Blocking finding R2-01 — prerequisite delivery gates remain weaker than the required closure contract

Canonical dependency truth remains unfinished: `MSR-201` and `MSR-202` are `in-progress` with commit/PR/CI evidence pending; `GBF-409` and `GBF-411` are `IN_PROGRESS`, with the latter on PR #2205 and exact-main delivery evidence incomplete.

The repaired task files correctly mark downstream work blocked, but several authoritative tasks still define the *hard dependency* only as `REVIEW-PASS/accepted contract` and then separately require only the downstream task's own protected merge/CI/exact-main package evidence. That leaves the task-local closure rule ambiguous and can permit downstream closure before the prerequisite itself has protected-merge + required CI + exact-main installable packaged E2E/Release evidence.

Concrete task-local gaps:

- `MSR-210-bot-durable-session-binding.md` line 8: hard dependency is only `MSR-201 REVIEW-PASS/accepted contract`; lines 21 and 52-54 record accepted head/PR/CI, while exact-main packaged closure at lines 54-56 is explicitly **this task's own** evidence.
- `MSR-211-bot-capability-policy-plane.md` line 8: hard dependencies are only `MSR-202 REVIEW-PASS`, `MSR-210 REVIEW-PASS`, `GBF-409/411 REVIEW-PASS/accepted contract`; line 9 accurately says delivery evidence is pending, but the task does not make prerequisite protected merge + required CI + exact-main packaged E2E/Release a prerequisite closure gate.
- `GBF-508-group-bot-behavior-capability-routing.md` line 8 has the same `REVIEW-PASS/accepted contract` dependency form for MSR-210/211 and GBF-409/411; its closure section is GBF-508's own delivery evidence.
- `TFI-M7-P0-001-group-bot-messaging-contract.md` line 8 hard-gates only M6-005/MSR-210/MSR-211/GBF-508 `REVIEW-PASS`; line 52 requires only TFI-M7's own protected merge/CI/exact-main package evidence.
- `TFI-M8-P0-002-install-miniapp-bot-projection.md` line 8 hard-gates only M8-001 and MSR-210 `REVIEW-PASS`; line 9 records MSR-201 pending, but line 48 requires only TFI-M8-002's own delivery lineage.

Required repair: in every authoritative downstream task that truly depends on those contracts, define dependency acceptance/closure explicitly as prerequisite **REVIEW-PASS + protected merge + required CI + exact accepted canonical-main installable/package E2E/Release evidence** (or a narrowly documented contract-only exception that explicitly forbids downstream closure and states who owns later delivery). Shared WBS/milestone prose must not substitute for task-local self-containment. While a dependency is incomplete, allowed prework and forbidden submit/accept/close scopes must remain explicit `BLOCKED`.

## Blocking finding R2-02 — TFI-M7 fallback gate is still weaker than GBF-508/MSR policy contract

`TFI-M7-P0-001-group-bot-messaging-contract.md` line 49 says fallback requires semantic/App/MiniApp capability genuinely unavailable, same-account paired device, control enabled, current `target/session/generation`, approval granted/unexpired, and fail-closed revoke/stale/deny/expire. It correctly forbids fallback for an available-but-denied semantic capability.

However, unlike GBF-508 line 57, TFI-M7's authoritative gate omits:

- current/not-revoked/not-stale **client** identity/generation state;
- explicit **MiniApp/install state permits** the requested fallback semantics;
- an explicit fallback-specific requirement that the resulting Computer Use action remains **audited and correlated end-to-end**. General correlation text exists at implementation step 4/contract acceptance, but it is not part of the fallback authorization predicate.

Required repair: make TFI-M7's fallback gate at least as strict as GBF-508: true semantic/App/MiniApp unavailability (not denial), same-account pairing, control enabled, current target/session/client/generation, approval granted and unexpired, MiniApp/install authorization, audited/correlated invocation/result, and fail-closed approval deny/expire, revoke/stale, unsafe-unavailable, and available-but-denied cases.

## CI observation — not an acceptance claim

For reviewed head `a5ce2e5...`, GitHub reports `CI` and `Project portfolio governance` succeeded, but `GBF release candidate regression` run `33876067936` failed in job `Canonical seven-gate regression`, step `Require every dispatched workflow to complete successfully on the same head`. This review does not classify that run as a required gate for this docs-only governance PR; it is recorded only so no one can state that all workflows on the head are green. No canonical-main packaged E2E/Release acceptance is inferred.

## Handoff

Return to the architecture project group. Repair only governance/task contracts under `projects/**`; do not implement application code in this review round. Preserve the prior rejection history. After repair, request a new real-diff review against the new head.
