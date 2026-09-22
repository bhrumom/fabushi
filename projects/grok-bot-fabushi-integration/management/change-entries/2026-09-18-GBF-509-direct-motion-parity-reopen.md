# Change entry — GBF-509 direct motion-parity re-open

Date: 2026-09-18

## Reason

User explicitly required the original Grok icon-study objective to remain incomplete until direct reference-vs-Fabushi visual/motion evidence passes thresholds declared before measurement.

## Durable changes

- pinned `bhrum/grok-icon-study` reference to `647e9bd7c60290c42a738fad586589b3f36a4680`;
- froze direct motion-parity thresholds before capture in `source/2026-09-18-grok-icon-reference-motion-parity.md`;
- froze deterministic scenarios/timeline in `desktop/e2e/fixtures/avatar-motion-parity.v1.json`;
- reopened GBF-509 and its WBS row from `RELEASED` to `IN_PROGRESS`.

## Architecture/provenance

No duplicate avatar runtime is introduced. Reference geometry, eye polygons, branding, extracted package code and reconstructed renderer remain test-reference-only and may not enter the Fabushi product/package.

## Rollback

If the acceptance harness itself is invalid, remove the harness/workflow in a follow-up PR but preserve this record and the frozen v1 commits. Do not rewrite v1 thresholds after observing capture results; open a separately justified v2 contract if required.
