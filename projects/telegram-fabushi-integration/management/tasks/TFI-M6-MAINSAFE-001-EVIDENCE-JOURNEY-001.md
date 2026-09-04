# TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001 — OWNERSHIP-001 packaged user journey evidence

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / NOT_STARTED`
- Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Dependency: completed canonical `TFI-M6-MAINSAFE-001-OWNERSHIP-001` semantics + `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` evidence plumbing.
- This task proves the completed ownership semantics at the packaged-user boundary; it does **not** reopen or rewrite `OWNERSHIP-001`.

## Missing evidence

The exact-main desktop suite contains broad Messenger and Grok journeys, but repository search and the failed test-release records do not identify one dedicated packaged journey proving the complete OWNERSHIP-001 acceptance chain. Existing generic full-video evidence belongs to other journeys and cannot substitute for an ownership-specific acceptance artifact.

## Required packaged journey

One deterministic packaged journey must exercise, through user-visible or packaged Host boundaries as appropriate:

1. send a message under the canonical ownership identity;
2. subscribe and unsubscribe without ownership/source-of-truth divergence;
3. request/approve Community join and observe the accepted membership projection;
4. observe unread projection/state after the relevant message/community transitions;
5. preserve the canonical Conversation/Community ownership identities established by OWNERSHIP-001.

Every meaningful step must be labelled and captured under the evidence contract (screenshots + complete video + trace/report/runtime logs + manifest).

## Future execution allowlist

- a new dedicated packaged acceptance spec under `desktop/e2e/` (preferred), or the smallest existing Messenger E2E spec if repository convention makes a new spec unnecessary;
- evidence-only fixture/helper data under `desktop/e2e/` needed for that journey.

No application/product source, Rust core, workflow, Cargo/dependency, version config, Android/iOS source, or unrelated tests are allowed in this task. Workflow/evidence plumbing belongs only to `EVIDENCE-CONTRACT-001`.

## Failure-stop rule

If the unweakened journey exposes a real semantic product failure in send/subscription/community approval/unread ownership behavior, **STOP immediately and return to architecture diagnosis**. Do not change product code in this task and do not relax, delete, skip, broaden timeouts, or rewrite assertions to make the journey pass.

## Acceptance

1. Dedicated journey title/id is stable and ownership-specific.
2. It executes against a packaged application/real test Host boundary, not a renderer-only mock that bypasses the ownership contract.
3. All required semantic steps pass with meaningful assertions.
4. Evidence for pass and failure conforms to `EVIDENCE-CONTRACT-001`, including step labels and exact identity metadata.
5. Independent code review passes the exact head.
6. Protected merge queue and canonical-main readback complete.
7. A new test-release session reruns the dedicated journey from the new exact-main SHA before any release authorization.
