# ADR-0015 — post-merge deterministic fixture and evidence provenance

- Status: Accepted
- Date: 2026-09-05
- Project: `FAB-P0001 / TFI`
- Accepted baseline observed: `main@63e49b87d1ca5ad64d988e73769bf4a4ed796a19`

## Context

The accepted MAINSAFE product/version lineage passed protected merge queue, but exact-main Native iOS later failed before `app-shell` became reachable. Separately, existing packaged/native evidence plumbing has inconsistent identity/retention and there is no single dedicated packaged OWNERSHIP acceptance journey. These are three different capabilities and must not be collapsed into one broad repair.

## Decision

1. Deterministic iOS auth/bootstrap input is an isolated fixture capability and reuses the existing app launch-environment / Feature Host dependency-injection seam.
2. Evidence plumbing is a separate cross-platform acceptance contract. Produced evidence must survive success/failure paths, bind to exact source/run/job/platform/journey identities, and target 90-day retention where permitted.
3. The OWNERSHIP packaged journey is a proof task, not a product implementation task. Its final acceptance evidence depends on the evidence contract already being accepted on canonical main.
4. Implementation of the iOS fixture and evidence contract may proceed in parallel. Journey authoring may also proceed where file allowlists do not overlap, but journey **acceptance closure** waits for the evidence contract canonical readback.
5. All three tasks independently require exact-head review, protected merge-group gates and canonical-main readback; Test Release remains fail-closed until all three have landed.

## Open-source-first / license impact

Reuse `actions/upload-artifact` (MIT), Microsoft Playwright (Apache-2.0), Swift XCTest reference (Apache-2.0), and existing repository Feature Host/test seams. No upstream implementation code is copied; no parallel artifact service, E2E framework, auth mocking framework or new dependency is introduced.

## Consequences

- deterministic fixture data cannot become a production-auth bypass;
- evidence from a different SHA/run/job/platform/journey cannot close acceptance;
- a 14-day Native artifact setting is insufficient when 90 days is permitted;
- real semantic product failures found by the proof journey return to Architecture rather than being fixed inside a test-only task;
- records-only task delivery being absent from canonical main is tracked independently from runtime test failure.
