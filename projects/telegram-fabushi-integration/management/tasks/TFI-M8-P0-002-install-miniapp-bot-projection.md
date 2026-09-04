# TFI-M8-P0-002 — MiniApp install -> visible Bot -> Mahayana session binding

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M8-P0-002`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependencies:** `TFI-M8-P0-001` and `MSR-210` must each independently complete: contract acceptance; independent code review `REVIEW-PASS`; protected canonical-main merge; every required CI check; and installable/packaged E2E plus Release evidence bound to that dependency's exact accepted canonical-main SHA. Review acceptance or downstream closure language alone never satisfies either dependency.
- **Dependency truth:** `MSR-210` itself is blocked by canonical `MSR-201`, currently `in-progress` with commit/PR/CI pending. Because this task references the MSR-201 chain, its session integration may proceed only after MSR-201 has the same full contract/review/protected-merge/required-CI/exact-main package-E2E/Release closure and MSR-210 subsequently completes its own full closure. `MSR-211` is not a current hard prerequisite because capability policy is out of scope; if implementation crosses that boundary, stop and add MSR-211 with the same full closure gate before editing that scope.
- **Parallel/prework:** before all dependencies fully close, source reading, field mapping and test-vector design are contract-only. No session-integration implementation may be submitted, accepted, claimed complete, or used to unblock downstream work.

## Objective
Make successful MiniApp installation idempotently establish/display its canonical Bot while binding that Bot to exactly one durable MSR Mahayana session.

## Exact implementation scope
- `desktop/src/miniapp-bot-projection.ts`: canonical Marketplace metadata -> Bot id/username/displayName/description/conversationId/naturalLanguage/menu/commands/calls projection; no duplicate Bot database.
- existing `InstallMiniApp` / marketplace install-state producer on the fully delivered M8-001 canonical-main lineage.
- `desktop/src/messaging-shell-v2.tsx`: only the Bot visibility/reopen projection seam if current projection is not already consumed.
- `native/mahayana-messaging/src/bot.rs`: only canonical Bot identity/transport model needed by TFI projection.
- fully delivered MSR-210 public session-binding contract; do not implement a second session registry in TFI.
- focused projection/install/restart/session integration tests.

## Implementation steps
1. Record M8-001 and MSR-210 exact accepted contracts/review heads, protected-main SHAs, required CI, exact-main installable/package E2E and Release evidence; also record the completed MSR-201 lineage behind MSR-210.
2. Read actual canonical Marketplace Bot metadata and the exact MSR-210 API from accepted canonical main; write exact field/session mapping here.
3. On install, derive/create-or-get Bot projection idempotently; show it immediately without restart and reconstruct from installed state after restart.
4. Reinstall/update reuses Bot and Mahayana session; define uninstall/disable/historical conversation lifecycle without hidden executable orphan.
5. Missing/invalid Bot metadata fails visibly; never fabricate identity.
6. Route Bot chat to the fully delivered MSR session binding; capability/tool routing is **out of scope** and remains MSR-211/GBF-508/M7 work.

## In scope
Install-state Bot projection, visibility/restart/idempotency, MSR-210 session binding, lifecycle tests.

## Out of scope
Capability policy plane, device/MiniApp tool routing, group privacy behavior, second contact/Bot/session store, local build/test.

## Acceptance by category
- **Dependency gate:** M8-001 and MSR-210 each have accepted contract + independent `REVIEW-PASS` + protected canonical merge + required CI + exact-accepted-main installable/packaged E2E and Release evidence; MSR-201 has the same full closure before MSR-210. Missing any item leaves this task BLOCKED.
- **Unit:** projection identity/idempotency, reinstall/update/uninstall/invalid metadata cases.
- **Contract:** one canonical MiniApp/Bot identity maps to one fully delivered MSR-210 session across restart; no duplicate contact/session authority.
- **Integration:** install state -> Bot projection -> Messenger visibility -> MSR-210 create-or-get session; restart reconstructs identical mapping.
- **E2E:** exact-main installable card/install -> Bot visible -> direct chat -> MiniApp open -> full close/relaunch -> same Bot/session journey.
- **Security:** forged/missing manifest Bot metadata cannot fabricate Bot/session; disabled/uninstalled lifecycle cannot leave a hidden executable identity.
- **Performance:** Bot projection appears from committed install state without app restart or long poll; record install-complete-to-Bot-visible timing and ensure no startup regression.

## Required write-back and evidence
Record each prerequisite's accepted contract/review head, protected-main SHA, required CI and exact-main package/E2E/Release evidence, then this task's branch/commit/PR/review/CI workflow-run-job/check/session mapping/evidence/status/changelog and cross-update TFI/MSR records. Dependency source presence or a downstream pass is never dependency evidence.

This task's own closure requires protected merge, required CI and exact-main **installable** packaged E2E/Release lineage. Evidence identity: main SHA, app version, platform, run/job, journey ID, timestamp, package, complete video, step screenshots, trace, HTML/native report, logs; pass/fail always-equivalent upload; 90-day target or recorded lower limit. Missing any prerequisite or own item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
