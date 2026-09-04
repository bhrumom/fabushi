# TFI-M8-P0-002 — MiniApp install -> visible Bot -> Mahayana session binding

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M8-P0-002`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependencies:** `TFI-M8-P0-001 REVIEW-PASS` and `MSR-210 REVIEW-PASS`.
- **Dependency truth:** canonical `MSR-201` is currently `in-progress` with commit/PR/CI pending; `MSR-210` therefore cannot reach accepted/review-pass until `MSR-201 REVIEW-PASS/accepted contract` is recorded. This task remains blocked.
- **Parallel/prework:** before dependencies pass, source reading and test-vector design are allowed; no session-integration implementation may be submitted or accepted.

## Objective
Make successful MiniApp installation idempotently establish/display its canonical Bot while binding that Bot to exactly one durable MSR Mahayana session.

## Exact implementation scope
- `desktop/src/miniapp-bot-projection.ts`: canonical Marketplace metadata -> Bot id/username/displayName/description/conversationId/naturalLanguage/menu/commands/calls projection; no duplicate Bot database.
- existing `InstallMiniApp` / marketplace install-state producer on accepted M8-001 head.
- `desktop/src/messaging-shell-v2.tsx`: only the Bot visibility/reopen projection seam if current projection is not already consumed.
- `native/mahayana-messaging/src/bot.rs`: only canonical Bot identity/transport model needed by TFI projection.
- accepted MSR-210 public session-binding contract; do not implement a second session registry in TFI.
- focused projection/install/restart/session integration tests.

## Implementation steps
1. Wait for and record exact accepted heads of M8-001 and MSR-210 (including MSR-201 prerequisite evidence) before session integration.
2. Read actual canonical Marketplace Bot metadata and MSR-210 API; write exact field/session mapping here.
3. On install, derive/create-or-get Bot projection idempotently; show it immediately without restart and reconstruct from installed state after restart.
4. Reinstall/update reuses Bot and Mahayana session; define uninstall/disable/historical conversation lifecycle without hidden executable orphan.
5. Missing/invalid Bot metadata fails visibly; never fabricate identity.
6. Route Bot chat to accepted MSR session binding; capability/tool routing is **out of scope** and remains MSR-211/GBF-508/M7 work.

## In scope
Install-state Bot projection, visibility/restart/idempotency, MSR-210 session binding, lifecycle tests.

## Out of scope
Capability policy plane, device/MiniApp tool routing, group privacy behavior, second contact/Bot/session store, local build/test.

## Acceptance by category
- **Unit:** projection identity/idempotency, reinstall/update/uninstall/invalid metadata cases.
- **Contract:** one canonical MiniApp/Bot identity maps to one accepted MSR-210 session across restart; no duplicate contact/session authority.
- **Integration:** install state -> Bot projection -> Messenger visibility -> MSR-210 create-or-get session; restart reconstructs identical mapping.
- **E2E:** exact-main installable card/install -> Bot visible -> direct chat -> MiniApp open -> full close/relaunch -> same Bot/session journey.
- **Security:** forged/missing manifest Bot metadata cannot fabricate Bot/session; disabled/uninstalled lifecycle cannot leave a hidden executable identity.
- **Performance:** Bot projection appears from committed install state without app restart or long poll; record install-complete-to-Bot-visible timing and ensure no startup regression.

## Required write-back and evidence
Record exact prerequisite review heads/commits, branch/commit/PR/review/CI workflow-run-job/check/session mapping/evidence/status/changelog here and cross-update TFI/MSR project records. The task cannot pass merely because MSR-210 source exists.

Closure requires this task's own protected merge, CI and exact-main **installable** packaged E2E/Release lineage. Evidence identity: main SHA, app version, platform, run/job, journey ID, timestamp, package, complete video, step screenshots, trace, HTML/native report, logs; pass/fail always-equivalent upload; 90-day target or recorded lower limit. Missing any item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
