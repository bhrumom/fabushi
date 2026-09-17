# FCM-026 — User-directed behavioral testing and release authority

- Project ID: `FAB-P0003`
- Project Key: `FCM`
- Task ID: `FCM-026`
- Started: `2026-09-18`
- Updated: `2026-09-18`
- Status: `implemented / protected-main merge pending`

## Objective

Remove the repository-wide requirement that formal publication must first pass Fabushi official MCP behavioral validation. Make the latest explicit user instruction authoritative for whether behavioral testing is performed and whether a candidate may be published.

## Acceptance criteria

1. Root `AGENTS.md` states that behavioral/product testing is run only when the user explicitly asks for testing.
2. Root policy states that Fabushi official MCP is optional unless the user explicitly requests MCP-based testing.
3. Root policy states that an explicit user instruction to publish / statement that a candidate may be published clears the behavioral-test gate without requiring unrequested MCP/E2E/smoke/regression validation.
4. Automatic E2E/behavioral workflows remain disabled by default and are not silently substituted for MCP.
5. `SOURCE_OF_TRUTH.md` and a dated source record identify the 2026-09-18 requirement as superseding conflicting mandatory MCP/E2E release gates.
6. An ADR records the durable decision and its consequences.
7. Non-behavioral release-construction/platform constraints remain distinct and truthful evidence states whether testing occurred.
8. The documentation change lands through normal protected-main governance; no behavioral/product test is run solely for this documentation change because the user did not request testing.

## Verification method

- Read back the branch versions of `AGENTS.md`, `SOURCE_OF_TRUTH.md`, the dated source, and ADR.
- Inspect the PR diff and protected-main readback after merge.
- Do not run MCP/E2E/smoke/regression/product-behavior testing for this task unless the user separately requests it.

## Implementation

- Branch: `docs/user-directed-test-release-policy-20260918`
- Baseline: `main@6245420379e6c11a84d23b2e705debe779532d47`
- Source: `projects/fabushi-cicd-merge-governance/source/2026-09-18-user-directed-test-and-release-authority.md`
- Decision: `projects/fabushi-cicd-merge-governance/decisions/ADR-0007-user-directed-behavioral-testing.md`
- Root policy and source-of-truth updates: implemented on branch.
- PR / protected-main merge / canonical readback: pending.
