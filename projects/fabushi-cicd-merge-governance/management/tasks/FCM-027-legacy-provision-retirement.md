# FCM-027 — Legacy production test-account provisioning retirement

Project FAB-P0003 / FCM; status active; 2026-10-14.

## Context and goal
User explicitly authorizes the attached next-generation layered testing proposal,
particularly isolated accounts. Canonical implementation now belongs to Backend
and Governance split repositories. This task is source-repository migration and
safety cleanup only, permitted by root routing policy exception 7.

## Requirements / current and target
R1: Retire this legacy workflow's routine production D1 writes. Keep a dispatched
failure explaining the canonical Backend isolated factory; never pretend success.
R2: Relabel legacy no-test CI truthfully as archival policy evidence; it cannot
claim product quality or forbid the now-authorized canonical test program.
R3: Do not delete existing production users, mutate secrets, or implement product
runtime in this repository. Canonical source is fabushi-governance FCM-027.

## Architecture / interfaces / constraints
Only legacy workflow controls change. No account schema/auth behavior changes.
No production environment or secrets in retired provisioning. All tests execute
only in Actions. Protected-main integration and readback remain required.

## Failures / strategy / verification
Dispatch after retirement fails with an actionable migration error. Implement
spec -> archived workflow -> Actions static contract/no-secret assertions -> PR
-> permitted integration -> main readback. Keep original users for separate audit.
Missing Actions results are blocked, never pass. Reverting production provisioning
is not an allowed isolation fallback; rollback requires a newer authorized policy.

## Acceptance / evidence
AC-1: R1..R3 exact-head Actions static retirement contracts pass and retained
workflows contain no production account mutation or incorrect product-pass claim.
AC-2: PR/main readback verifies the retirement. Real isolated account/runtime
acceptance is Backend responsibility, not satisfied by this cleanup test.

## Provenance
User attachment preserved verbatim in canonical Governance FCM-027 source dated
2026-10-14. Root AGENTS.md routing exception; historical FCM-023/024/026 sources.
Canonical Backend docs/specs/isolated-ci-account-factory.md.

## Compliance
| Criterion | Status | Evidence / reason |
| --- | --- | --- |
| R1..R3 / AC-1 | blocked | Exact-head Actions pending |
| AC-2 | blocked | PR/integration pending |
