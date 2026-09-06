# TFI-M6-MAINSAFE-001 evidence index

This directory indexes durable evidence for MAINSAFE recovery. GitHub PR/Actions state remains authoritative for live facts.

## Architecture evidence — newest first

- `POSTMERGE-BLOCKER-RAW-EVIDENCE-2026-09-05.md` — **authoritative latest**: accepted `main@63e49b87...`, #2345 protected merge provenance, exact-main Electron SUCCESS, Native iOS raw failure/job/xcresult, task-file 404 topology distinction, test-release records branch provenance, open-source-first evidence research.
- `VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md` — historical predecessor diagnosis that froze the event-aware exact-head successor.
- `VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md` — historical bootstrap dependency-cycle diagnosis.
- `VERSION-GUARD-BLOCKER-DIAGNOSIS-2026-09-05.md` — historical required canonical-version topology diagnosis.
- `POSTMAIN-FAILURE-DIAGNOSIS-2026-09-05.md` — earlier post-main failure decomposition; superseded where its baseline/run differs from the accepted-main record above.

## Current stable atomic contracts

- `../../management/tasks/TFI-M6-MAINSAFE-001-IOS-FIXTURE-001.md` — `M6-PM-IOSF-R01 / M6-PM-IOSF-A01`.
- `../../management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001.md` — `M6-PM-EVC-R01 / M6-PM-EVC-A01`.
- `../../management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001.md` — `M6-PM-EVJ-R01 / M6-PM-EVJ-A01`.
- Architecture handoff/dependency boundary: `../../management/90-2026-09-05-M6-MAINSAFE-001-POSTMERGE-BLOCKER-重规划与执行交接.md`.
- Evidence/provenance ADR: `../../decisions/ADR-0015-postmerge-deterministic-fixture-and-evidence-provenance.md`.

## Historical execution/review provenance

- #2341 @ `2241c856fb3da498ac99ade89007fe01dd335183` — version-only historical blocked provenance.
- #2342 @ `570b874318bfe42406c6f46f51798baed8c89e48` — guard-only historical blocked provenance.
- #2343 @ `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa` — review-failed bootstrap candidate.
- #2344 @ `b60b8e2483333db21ca6cea068b7a1be9c0f4851` — independent review provenance.
- #2345 @ `9c46c1d8f030be390995cc78f321aac0d96b7f44` — accepted via protected merge queue to canonical `63e49b87...`.

## Current evidence order

accepted canonical main -> independent atomic implementation(s) -> current-head evidence -> independent Code Review -> protected `merge_group` required gates -> canonical-main readback -> after all three acceptances, one fresh exact-main packaged/native Test Release -> later Stable Release gate.

No manual/rerun/historical/different-SHA evidence, foreign artifact, skipped/neutral gate, or similarly named check can substitute for this order.
