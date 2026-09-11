# FCM-019 — Shopify-style CLI/UI decoupled fast automation

## Status

`in-progress`

## Source

- `projects/fabushi-cicd-merge-governance/source/2026-09-11-shopify-style-cli-ui-fast-automation.md`
- User source: https://mp.weixin.qq.com/s/DEg20nFKfrd2urMc3BjntA
- Shopify Engineering baseline: “Keeping Developers Happy with a Fast CI” (2021).

## Objective

Turn Fabushi's existing Mahayana Core test-driver + Host/UI journey infrastructure into a faster GitHub Actions development loop modeled on Shopify's test-selection principle: do not pay for unrelated work on every pull request, but fail safe to complete validation whenever the impact cannot be proven narrow.

The product architecture remains one core plus thin surfaces:

- Mahayana Rust/Product Core owns business behavior.
- Presentation-neutral test-driver exercises real core/product operations without launching full UI.
- Host/UI fast E2E exercises interaction/contract wiring independently.
- Packaged/native/device E2E remains canonical-main/release evidence.

## Atomic work

### FCM-019.1 — Verify baseline and upstream method

Status: `implemented`

Acceptance:
- canonical main SHA recorded before changes;
- current Mahayana/test-driver/Host workflows inspected;
- Shopify official fast-CI test-selection method reviewed;
- no new third-party CI dependency introduced without review.

Evidence:
- intake main: `d8bb64f44a7d97b38d8ac10d2193c8b1cb95f0f4`;
- existing `mahayana-test-driver-protocol` explicitly delegates product operations to the real backend;
- existing `host-fast-e2e.yml` already provides an independent deterministic UI lane;
- Shopify Engineering reports affected-test selection and skipping unnecessary setup as major CI latency levers.

### FCM-019.2 — Add conservative affected-test selector

Status: `implemented-on-branch`

Acceptance:
- selector consumes changed paths and emits stable test groups;
- canonical push/manual always select full suite;
- merge-queue revalidation always selects full suite;
- workspace/shared/native/unknown inputs fall back to full suite;
- modeled leaf changes select only required consumer groups;
- selector has deterministic unit tests;
- selection reason/groups are written to GitHub Step Summary;
- changes to the shared `tools/fabushi-test/suites.json` registry fail safe to full selection;
- main/merge-group runs use exact-SHA concurrency and cannot be cancelled by a later accepted SHA.

Implementation:
- `scripts/select-mahayana-fast-tests.py`
- `scripts/tests/test_select_mahayana_fast_tests.py`
- `.github/workflows/mahayana-fast-checks.yml`

Continuation evidence (2026-09-11):
- implementation commit `b4da137b509d0da921038b40cd5aca1a4fa2cd0a` adds `merge_group: checks_requested`, exact-SHA concurrency for non-PR events, and registry-triggered full fallback;
- selector unit coverage is now 13 deterministic cases, including merge-group full fallback and shared-suite-registry full fallback;
- GitHub Actions evidence for the new head is still required; absence of a surfaced run is not treated as success.

### FCM-019.3 — Preserve Core/UI separation

Status: `implemented-existing`

Acceptance:
- Rust/Core fast gate does not launch desktop/mobile UI;
- Host fast E2E remains a separately triggered deterministic UI contract lane;
- package/device tests are not moved onto ordinary PR hot path.

Evidence:
- `docs/fast-feature-testing.md`
- `.github/workflows/host-fast-e2e.yml`
- `contracts/automation/cross-platform-journeys.json`
- `mahayana-test-driver-protocol` and `mahayana-cli` test-driver backend.

### FCM-019.4 — First-class developer CLI test entry

Status: `pending`

Acceptance:
- a debug/test-only Mahayana CLI entry runs a local no-UI/no-credential smoke suite through the existing real `ProductBackend` / `MahayanaProductClient` control plane;
- explicit online mode can probe public marketplace behavior without UI;
- release builds remain unable to include the test-driver surface;
- GitHub Actions exercises the entry point.

The existing `mahayana-test-driver` JSONL binary is the required backend and is not to be replaced by a fake test model.

### FCM-019.5 — Prove actual PR latency reduction safely

Status: `pending`

Acceptance:
- this workflow-change PR itself runs full fallback because the selector/workflow changed;
- after the selector lands, an objective leaf-change run demonstrates a reduced group selection;
- full-fallback fixture and actual canonical-main push demonstrate complete selection;
- timing/cache evidence is retained in Actions metadata/summary.

### FCM-019.6 — Protected merge and exact-main validation

Status: `pending`

Acceptance:
- required PR checks green;
- change merges through repository-protected process;
- exact merged main SHA is read back;
- exact-main `Mahayana fast checks` selects and passes full suite;
- downstream delivery gates remain non-regressed or objective blocker is recorded.

## Current branch

- `ci/fcm-019-shopify-fast-automation-20260911`

## Current dependency / blocker

- PR #2513 is intentionally stacked behind PR #2503 (`codex/fcm-cli-first-test-loop-20260911`).
- PR #2503 current exact head `d1019ccc7bbc393a9d26061572ece3d43df939f5` has green CI/product gates, but a fresh independent review of that exact head is still required before protected enqueue; older-head review results are not sufficient.
- #2513 must be synchronized onto the eventual accepted canonical main from #2503 before it can be marked ready or merged.

## Safety / fail-closed rules

- Never infer narrow impact for an unmodeled Mahayana path.
- Do not replace real Product Core operations with automation-only success responses.
- Do not weaken canonical main/package/device acceptance to make PR CI faster.
- Do not mark FCM-019 passed until FCM-019.4 through FCM-019.6 have objective GitHub evidence.
