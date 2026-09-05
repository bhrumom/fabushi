# TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001 — OWNERSHIP packaged user journey evidence

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / READY_FOR_EXECUTION_HANDOFF`
- Requirement ID: `M6-PM-EVJ-R01`
- Acceptance ID: `M6-PM-EVJ-A01`
- Accepted product baseline: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
- Dependency: completed canonical OWNERSHIP semantics + `M6-PM-EVC-A01` for final evidence-contract acceptance.
- Purpose: prove the already-completed ownership semantics at the packaged-user boundary; do not reopen/rewrite product ownership code.

## M6-PM-EVJ-R01 — requirement

Provide one stable, deterministic, packaged-application acceptance journey that proves the completed OWNERSHIP boundary through user-visible/real Host paths: canonical send identity, subscribe/unsubscribe, Community join request/approval, unread projection, and preserved Conversation/Community ownership identities.

This task already existed on #2340 and is reused. Its exact path remains 404 on accepted `main@63e49b87...`; that records-delivery topology gap is separate from whether the packaged journey exists/passes.

## Required journey

One stable journey/test ID must cover, in order or in explicit labelled substeps:

1. send a message under the canonical ownership identity;
2. subscribe and unsubscribe without ownership/source-of-truth divergence;
3. request and approve Community join, then observe the accepted membership projection;
4. observe unread projection/state after the relevant message/community transitions;
5. assert the canonical Conversation/Community ownership identities remain unchanged.

The journey must execute against a packaged application and real test Host boundary. Renderer-only mocks that bypass ownership/Host behavior do not satisfy this requirement.

## Inputs / dependencies / parallel boundary

- implementation starts from freshly re-read canonical main (currently `63e49b87...`);
- task contract is read from latest #2340 head;
- existing packaged Messenger E2E fixtures are the preferred basis;
- journey authoring may proceed in parallel with `IOS-FIXTURE-001` and `EVIDENCE-CONTRACT-001` where files do not overlap;
- **acceptance closure is ordered:** `EVIDENCE-CONTRACT-001` must first pass independent review, protected merge, and canonical-main readback so this journey's final proof is emitted under the accepted evidence contract.

## Exact implementation allowlist

- one new dedicated packaged acceptance spec under `desktop/e2e/` (preferred), or the smallest existing Messenger packaged E2E spec if repository convention makes a new spec unnecessary;
- evidence-only fixture/helper data under `desktop/e2e/` required solely for this journey;
- task-specific records under `projects/telegram-fabushi-integration/**`.

## Forbidden files / actions

- all application/product source and Rust core;
- all `.github/workflows/**` (evidence plumbing belongs only to `EVIDENCE-CONTRACT-001`);
- Cargo/dependency/lockfile, version/release config, Android/iOS source;
- unrelated tests;
- relaxed/deleted/skipped assertions, timeout inflation, retry inflation, renderer-only substitution, or semantic expected-value rewrites.

Any real semantic product defect found by the unweakened journey is a new architecture blocker, not permission to modify product code in this task.

## Evidence binding

For every accepted run, evidence must bind: packaged app identity/version, platform/OS, exact canonical main SHA, workflow/run id, job id/name, stable journey/test ID, result, UTC timestamp, and the screenshots + complete video + trace + HTML/report + runtime logs required by `M6-PM-EVC-R01`. A different run/SHA/platform/test cannot substitute.

## Open-source-first decision

Reuse the repository's existing Playwright packaged Messenger test stack and fixture conventions. Playwright is mature upstream under Apache-2.0; no copied upstream implementation and no new framework/dependency is required. Reject a parallel E2E framework or product-only mock harness because it would weaken provenance and duplicate the existing packaged acceptance system.

## M6-PM-EVJ-A01 — acceptance / gates

1. Stable ownership-specific journey/test ID exists inside the exact allowlist.
2. It runs against a packaged app/real Host boundary and all five required semantic steps pass with meaningful assertions.
3. Final proof is generated only after `M6-PM-EVC-A01` is present on canonical main and conforms to that evidence contract, including exact packaged app/platform/SHA/run/job/test identity.
4. Independent Code Review approves the exact journey head, semantic coverage and non-weakening rule.
5. Protected `merge_group` required gates pass; then canonical main is re-read and proves the reviewed journey landed.
6. Test Release reruns the dedicated journey from the new exact-main SHA; a prior PR-head or historical artifact cannot close it.
7. Any semantic product failure, evidence identity mismatch, renderer-only bypass, or scope expansion fails closed to Architecture.
