# PR #2320 independent code review R3 — TFI

- Project: `FAB-P0001 / TFI`
- Review target PR: `#2320`
- Target branch: `arch/p0-recovery-20260904`
- Canonical base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed repair commit: `a116f63b9d7d1f89422069605caebbb8475f0567`
- Reviewed evidence/handoff commit and exact target head: `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f`
- Target PR state at review: `open`, `merged=false`, `mergeable_state=unstable`
- Review verdict for this exact target head: **`REVIEW-PASS`**
- Review-record branch: `review/pr-2320-r3-20260904-e2207ee`

## Historical review preservation

R2 remains immutable history: review-record PR `#2321@a9e965a9a4dfd47baeb72742a29e6ef3eda402c2`, GitHub review id `5113492839`, target head `a5ce2e522cf124910c6627c72a646513b90960fa`, verdict `REVIEW-REJECTED`. This R3 record does not edit, dismiss, rewrite, or reinterpret that history.

## Scope and changed-file boundary

GitHub reports **79 changed files total** for PR #2320 at the reviewed head: TFI 30, MSR 26, GBF 23. Every changed file is under `projects/**`. No application source, root `AGENTS.md`, `.github/workflows/**`, CI/workflow implementation, `projects/PORTFOLIO.json`, or `projects/PROJECT_ID_POLICY.md` is changed by the target PR.

Exact TFI changed files (30):

1. `projects/telegram-fabushi-integration/PROJECT.yaml`
2. `projects/telegram-fabushi-integration/README.md`
3. `projects/telegram-fabushi-integration/SOURCE_OF_TRUTH.md`
4. `projects/telegram-fabushi-integration/decisions/ADR-0014-mahayana-bot-miniapp-cross-project-contract.md`
5. `projects/telegram-fabushi-integration/docs/2026-09-04-p0-architecture.md`
6. `projects/telegram-fabushi-integration/docs/2026-09-04-p0-release.md`
7. `projects/telegram-fabushi-integration/docs/2026-09-04-p0-requirements.md`
8. `projects/telegram-fabushi-integration/docs/2026-09-04-p0-security.md`
9. `projects/telegram-fabushi-integration/docs/2026-09-04-p0-testing.md`
10. `projects/telegram-fabushi-integration/evidence/FAB-ARCH-P0-20260904/ARCHITECTURE-REPAIR-PR-2320-R2.md`
11. `projects/telegram-fabushi-integration/evidence/FAB-ARCH-P0-20260904/ARCHITECTURE-REPAIR-PR-2320.md`
12. `projects/telegram-fabushi-integration/evidence/FAB-ARCH-P0-20260904/CODE-REVIEW-PR-2320.md`
13. `projects/telegram-fabushi-integration/evidence/FAB-ARCH-P0-20260904/README.md`
14. `projects/telegram-fabushi-integration/management/09-2026-09-04-P0-WBS.md`
15. `projects/telegram-fabushi-integration/management/10-2026-09-04-P0-里程碑.md`
16. `projects/telegram-fabushi-integration/management/11-2026-09-04-P0-验收追踪.md`
17. `projects/telegram-fabushi-integration/management/12-2026-09-04-P0-风险与依赖.md`
18. `projects/telegram-fabushi-integration/management/13-2026-09-04-P0-变更日志.md`
19. `projects/telegram-fabushi-integration/management/2026-09-04-PR-2320-code-review-R2-repair.md`
20. `projects/telegram-fabushi-integration/management/2026-09-04-PR-2320-code-review.md`
21. `projects/telegram-fabushi-integration/management/tasks/TFI-M3-P0-001-desktop-first-message-hydration.md`
22. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-repair-compile-and-community-create-boundary.md`
23. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-002-community-canonical-membership-recovery.md`
24. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-003-community-admission-authz-negative-contracts.md`
25. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-004-recipient-neutral-journal-replay.md`
26. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-005-protocol-v3-reader-boundary.md`
27. `projects/telegram-fabushi-integration/management/tasks/TFI-M7-P0-001-group-bot-messaging-contract.md`
28. `projects/telegram-fabushi-integration/management/tasks/TFI-M8-P0-001-generated-miniapp-open-card.md`
29. `projects/telegram-fabushi-integration/management/tasks/TFI-M8-P0-002-install-miniapp-bot-projection.md`
30. `projects/telegram-fabushi-integration/source/2026-09-04-p0-recovery-architecture.md`

## R3 gate results

### A — task-local dependency closure: PASS

All affected authoritative tasks were read individually, not sampled. The relevant TFI tasks now state prerequisite closure inside the task itself. Where a prerequisite exists, completion requires that prerequisite's own contract acceptance + independent code review `REVIEW-PASS` + protected canonical-main merge + every required CI check + installable/packaged E2E and Release evidence bound to the prerequisite's exact accepted canonical-main SHA. Shared release prose, downstream closure, source presence, or shorthand `accepted` cannot replace that lineage. Tasks with unmet prerequisites remain `BLOCKED` or strictly `contract-only`.

`TFI-M8-P0-002` separately gates TFI-M8-P0-001 and MSR-210 with the complete rule and preserves the transitive MSR-201 blocker. `TFI-M7-P0-001` separately gates TFI-M6-P0-005, MSR-210, MSR-211 and GBF-508 with complete closure, while retaining the transitive MSR-201/MSR-202/GBF-409/GBF-411 lineage.

Live prerequisite truth checked against canonical main: MSR-201 and MSR-202 remain `in-progress`; GBF-409 and GBF-411 remain `IN_PROGRESS`. No pending prerequisite is promoted to passed.

### B — TFI-M7 semantic -> Computer Use fallback: PASS

The task itself, its acceptance section, dependency/risk records, and test/release handoff now use the same fail-closed predicate as GBF-508. Fallback requires genuine semantic/App/MiniApp unavailability, not available-but-denied; same-account paired device; control enabled; current/non-stale/non-revoked target, Mahayana/Bot session, client and generation; granted unexpired approval; explicit current MiniApp/install state permitting fallback; and end-to-end audit/correlation. Denied/expired approval, stale/revoked identities, unpaired or account-mismatched device, disabled control, MiniApp/install disallow, semantic available-but-denied, or missing audit/correlation all fail closed.

### C — other authoritative task and M6 regression gates: PASS

All 13 cross-project authoritative tasks were reviewed individually. Each is independently dispatchable as a record and contains identity, source/module boundary, dependencies and parallel conditions, steps, in-scope/out-of-scope, unit/contract/integration/E2E/security/performance acceptance (or explicit N/A handling), and write-back requirements.

TFI M6 facts remain precise: audited implementation input is `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`; M6-001 preserves the `RespondCommunityJoin` bool/`Option<Event>` compile defect and the `service.rs` Community-backed `CreateConversation -> UpsertConversation` boundary defect; M6-003 correctly treats no-Community `RequestCommunityJoin -> CommunityNotFound` as existing correct behavior/regression gate rather than inventing a `CommunityState::new()` defect. The public/private/invite/join-request positive/negative admission matrix remains present.

### D — root AGENTS evidence contract: PASS as governance contract; runtime delivery remains unproven

Task-local and release/testing records require exact accepted canonical-main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, installable/package artifact, complete user-journey video, step screenshots, trace, HTML/native report and logs; pass and fail artifacts use `always()`-equivalent upload; retention target is 90 days or a recorded provider limitation; packaged/installable app evidence is mandatory. Docs-only CI is explicitly insufficient.

No runtime/release success is claimed. Historical GBF release-candidate regression run `33876067936` remains `failure`. On the exact reviewed head, `33880432540` (GBF release candidate regression) is also `failure`; `33880472952` (Electron desktop quality gate) is `failure` with Linux failing the canonical-architecture precheck and Windows failing the packaged user journey; `33880475811` (Native mobile quality gate) is `failure` with iOS SwiftUI unit/simulated-user UI tests failing. These red runs remain red repository/runtime gates and are not reclassified as task acceptance, packaged canonical-main E2E, or Release evidence.

### E — implementation-time provenance / clean-room boundary: PASS

MSR-107 requires implementation-time exact-file provenance for every adopted upstream implementation: upstream repo, exact file, revision, license, NOTICE/attribution disposition, Fabushi target, adaptation/reimplementation decision, and reviewer result. Architecture pins do not substitute for execution evidence. Reconstructed Grok is limited to clean-room observable behavior/UI/IPC reference; copying, translating, porting or templating its implementation is forbidden.

### F — governance boundary/history: PASS

Target changes stay under `projects/**`; registered identities remain FAB-P0001/TFI, FAB-P0005/MSR and FAB-P0004/GBF; no new Project ID is created; root governance/portfolio/project-ID files are unchanged. The repair commit chain is real: `a116f63b...` follows the R2-reviewed architecture head and `e2207ee0...` follows `a116f63b...`; R2 review PR #2321 and review id 5113492839 remain untouched.

## Authorization and unresolved dependencies

**R3 verdict: `REVIEW-PASS` for PR #2320 at exact head `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f`.** This is a governance/content review, not a claim that PR #2320 is merged or that required CI/runtime/package/release gates are green.

Only this new R3 `REVIEW-PASS` authorizes the execution group to enter the atomic-task workflow for the reviewed contracts. It does not waive task status or dependency gates: MSR-201/MSR-202 are still in progress, GBF-409/GBF-411 are still in progress, and every dependent task explicitly marked `BLOCKED` remains blocked/contract-only until each prerequisite reaches its own full closure. Repository-required red checks likewise remain red and must be satisfied where branch/release policy requires them.

Reviewer did not run local build/test and did not modify application source, CI/workflows, root `AGENTS.md`, portfolio registry, Project ID policy, or prior review history.