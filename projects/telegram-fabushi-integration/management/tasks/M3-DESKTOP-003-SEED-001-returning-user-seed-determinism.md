# M3-DESKTOP-003-SEED-001 — returning-user seed/setup determinism

- **Project**: `FAB-P0001 / TFI`
- **Parent**: `M3-DESKTOP-003`
- **State**: `FROZEN / NEXT-ONLY-EXECUTABLE`
- **Date**: 2026-09-05
- **Architecture baseline**: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- **Failure input**: product PR #2349 exact head `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`; test-driven acceptance comment `5551040795`; records-only failure PR #2350 head `20e0b5b38a97215cc3beb3bed1f67332e075aeee`; Electron run `33959034172`, Linux job `101287508113`.

## Goal

Make only the returning-user **scenario setup** deterministic so the target test reaches its existing history-seeding/relaunch measurement path on the original attempt. This task does not diagnose or repair the product startup path.

The observed Linux failure is bounded to setup: after creating and selecting `首屏性能验收`, the test immediately reads `fabushi.desktop.messenger-projection.v1.activePeerKey`; one packaged attempt observed an empty value and failed `expect(seededConversationId).not.toBe('')`, while retry #1 passed and emitted P0–P9. This is not evidence of the reported ~1 minute product delay.

## Dependencies

1. Existing diagnostic implementation and instrumentation from `M3-DESKTOP-003` / PR #2349.
2. Exact failure evidence from run `33959034172` / Linux job `101287508113` and PR #2350.
3. No dependency on `M3-DESKTOP-003-EVIDENCE-001`; that task is downstream.
4. `M3-DESKTOP-004` remains blocked and is not an input implementation task.

## Execution-group input files

Read before editing:

- `projects/telegram-fabushi-integration/SOURCE_OF_TRUTH.md`
- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-003-startup-first-message-diagnostics.md`
- this task file
- `desktop/e2e/messenger.spec.ts` at the final execution base/head
- PR #2349 comment `5551040795`
- PR #2350 failure record
- raw Linux log for run `33959034172`, job `101287508113`

## Implementation allowlist

Product/test implementation allowlist is **exactly**:

- `desktop/e2e/messenger.spec.ts`

Task-specific records/evidence may additionally change only under:

- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-003-SEED-001-returning-user-seed-determinism.md`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/**`
- task-specific TFI status/handoff records required by project governance.

Any need to touch `desktop/src/**`, `desktop/electron/**`, `native/**`, `.github/workflows/**`, auth/runtime/protocol/schema/version/release files, dependencies, or another project is a **scope-expansion blocker** and must return to Architecture.

## Required implementation semantics

- Use the real user journey already present: login → create channel → select created channel → observe authoritative/persisted conversation identity → seed 32 messages → prove durable projection → close process → relaunch.
- Replace the racy immediate identity read only with an explicit readiness/synchronization contract grounded in product-observable state already emitted by the existing journey.
- Do **not** fabricate `activePeerKey`, conversation IDs, projection data, Host state, auth state, or messages directly in localStorage/native persistence as a bypass.
- Do **not** add arbitrary fixed sleep as the sole correctness condition.
- Do **not** increase retries, weaken the non-empty assertion, skip the target case, or treat retry success as acceptance.
- Preserve `M3-DESKTOP-003` diagnostic-only behavior; do not change startup behavior or make a root-cause claim.

## Test-driven acceptance

The test-driven acceptance group must independently verify on the final exact product head:

1. The target packaged returning-user scenario reaches a non-empty created conversation identity on the **original attempt** (`retry = 0`) before history seeding.
2. The synchronization condition proves the created channel is selected and its identity is available through an existing product-observable authority; no direct fixture fabrication/test-only product bypass is introduced.
3. The 32-message history seed and existing durable `readClientPersistence` pre-close condition remain intact.
4. Full process relaunch uses the same app-data directory and the same persisted returning-user state.
5. Existing P0–P9 instrumentation remains present and `rootCauseClaim` remains `null` unless a later architecture round authorizes otherwise.
6. Linux packaged target must not require Playwright retry to pass. Windows/macOS must remain green for the same target journey.
7. No product startup semantics, Host/auth semantics, protocol/schema, workflow, release, version, dependency, MiniApp, Mahayana CLI, MSR, or GBF behavior changes.
8. Heavy verification runs in GitHub Actions; no local native/build/package/E2E evidence substitutes for exact-head CI.

Failure of any item is `TEST-FAIL / BLOCKED`; no merge/test-release/stable-release authorization follows.

## Forbidden overreach

- No product performance fix.
- No `M3-DESKTOP-004` implementation.
- No change to runtime sync limits or startup constants.
- No auth, Host lifecycle, Rust messaging, persistence schema, or projection product-semantics change.
- No workflow/retry-policy change.
- No MiniApp/Mahayana/GBF/MSR work.
- No review, merge, protected queue, test release, or stable release in the execution session.

## Handoff relation

`M3-DESKTOP-003-SEED-001` is the **only next executable task**. After its execution PR reaches a final exact head, it goes to the test-driven acceptance group. Only an independent `TEST-PASS` with original-attempt deterministic setup unlocks `M3-DESKTOP-003-EVIDENCE-001`. If the execution discovers that determinism requires any out-of-allowlist product semantic change, stop and return to Architecture instead of widening scope.