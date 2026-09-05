# M3-DESKTOP-003-EVIDENCE-001 — exact-scenario evidence capture

- **Project**: `FAB-P0001 / TFI`
- **Parent**: `M3-DESKTOP-003`
- **State**: `FROZEN / BLOCKED-BY-SEED-001`
- **Date**: 2026-09-05
- **Architecture baseline**: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- **Failure input**: PR #2349 exact head `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`; test comment `5551040795`; records-only failure PR #2350 head `20e0b5b38a97215cc3beb3bed1f67332e075aeee`; run `33959034172`.

## Goal

Close only the evidence-contract gap for the exact packaged returning-user scenario. The successful target attempt already produced timing JSON, P0–P9 critical-path JSON and a screenshot, but the acceptance package had no dedicated target `.webm` and no explicit Electron app/main-process logs. Separate Grok visual-evidence videos are not substitutable evidence.

This task does not change product startup behavior and does not claim a root cause.

## Dependency

Hard dependency: `M3-DESKTOP-003-SEED-001` must first receive independent `TEST-PASS` proving deterministic original-attempt setup. Retry-dependent evidence is inadmissible.

## Execution-group input files

Read before editing:

- `projects/telegram-fabushi-integration/SOURCE_OF_TRUTH.md`
- `management/tasks/M3-DESKTOP-003-startup-first-message-diagnostics.md`
- `management/tasks/M3-DESKTOP-003-SEED-001-returning-user-seed-determinism.md`
- this task file
- `desktop/e2e/messenger.spec.ts`
- `desktop/e2e/grok-visual-evidence.spec.ts` as read-only repository precedent for `page.screencast.start/stop`
- `desktop/playwright.config.ts` as read-only evidence that `test-results/**` is the output directory and video/trace are enabled
- PR #2349 comment `5551040795`, PR #2350, and exact run `33959034172`

## Implementation allowlist

Product/test implementation allowlist is **exactly**:

- `desktop/e2e/messenger.spec.ts`

Task-specific records/evidence may additionally change only under:

- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-003-EVIDENCE-001-exact-scenario-evidence-capture.md`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/**`
- task-specific TFI status/handoff records required by governance.

`desktop/playwright.config.ts`, `desktop/e2e/grok-visual-evidence.spec.ts`, `.github/workflows/**`, product source, native source, dependencies and release/version files are **read-only / forbidden** for this atomic task. Existing diagnostics already upload `desktop/test-results/**`; a workflow change is not authorized merely to collect files written under `testInfo.outputPath(...)`.

## Required evidence semantics

Within the exact returning-user test, capture artifacts from the same original-attempt packaged journey:

- dedicated target user-journey video, e.g. `m3-desktop-003-returning-user.webm`, produced by the target page itself and attached to that test;
- explicit app/main-process stdout/stderr log file(s) associated with the same Electron application launch(es), stored under the target test output directory and attached;
- existing `startup-performance.json`;
- existing `startup-critical-path.json` with P0–P9, exact head and `rootCauseClaim: null`;
- target screenshot(s) and Playwright trace;
- a small manifest or attachment metadata sufficient to bind scenario/task ID, exact head, platform and attempt to those files.

Evidence capture must run on success, not only on failure. It must not log secrets/tokens/credentials.

## Test-driven acceptance

The test-driven acceptance group must independently verify on a new final exact product head:

1. Seed/setup passes on the original attempt; otherwise stop and return to `SEED-001`/Architecture.
2. On Linux, macOS and Windows packaged target journeys, each accepted target attempt has a dedicated `.webm` created by `M3-DESKTOP-003` returning-user case; another test's video is invalid.
3. The same target output contains app/main-process log file(s) covering launch/close/relaunch boundaries relevant to the scenario; files are non-empty or explicitly document a platform stream limitation as a failure requiring architecture replan, not silently omitted.
4. Timing JSON, P0–P9 JSON, screenshot(s), trace, video and process logs are all attributable to the same task/scenario, exact head, platform and original attempt.
5. Existing diagnostics upload exposes these artifacts through the already-covered `desktop/test-results/**` path; no workflow change is required or accepted.
6. P0–P9 remain monotonic, `diagnosticOnly: true`, and `rootCauseClaim: null` unless a later architecture round authorizes a claim.
7. Evidence capture does not alter startup behavior, retry policy, Host/auth/protocol/persistence semantics or timing target.
8. Logs are sanitized and do not persist secrets.
9. Heavy verification is GitHub Actions exact-head only.

Failure is `TEST-FAIL / BLOCKED`. A green aggregate job without the target artifacts does not satisfy acceptance.

## Forbidden overreach

- No product startup/performance fix and no `M3-DESKTOP-004` implementation.
- No workflow/retry/release/version change.
- No edits to Grok visual evidence or reuse of its video as target proof.
- No MiniApp, Mahayana CLI, MSR or GBF changes.
- No product source, native source, schema, dependency or security-boundary changes.
- No merge, test release or stable release in the execution or acceptance session.

## Handoff relation

Only after `SEED-001` independently passes may this task be executed. Its final exact execution head goes to test-driven acceptance. If both subtasks pass, the parent `M3-DESKTOP-003` returns to Architecture for evidence-based classification: either a measured bottleneck exists and Architecture may unfreeze a narrowly scoped `M3-DESKTOP-004`, or the reported ~1 minute delay remains non-reproduced and Architecture must define a new reproduction boundary rather than guessing a fix.