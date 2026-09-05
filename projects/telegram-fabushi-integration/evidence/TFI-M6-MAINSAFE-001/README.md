# TFI-M6-MAINSAFE-001 evidence index

This directory indexes durable evidence for the MAINSAFE post-main recovery. GitHub PR/Actions state remains authoritative for live facts.

## Architecture evidence

- `POSTMAIN-FAILURE-DIAGNOSIS-2026-09-05.md` — original exact-main failure decomposition.
- `VERSION-GUARD-BLOCKER-DIAGNOSIS-2026-09-05.md` — diagnosis that #2341 lacked the required canonical-version topology.
- `VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md` — dependency-cycle diagnosis that froze the original same-head bootstrap attempt.
- `VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md` — **authoritative latest** diagnosis: #2343's green canonical child actually checked out synthetic PR merge SHA `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac` rather than product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`; freezes the event-aware successor task.

## Historical execution/review provenance

- `VERSION-CONTRACT-001` / PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`; execution blocker comment `5547296411`.
- `VERSION-GUARD-CI-001` / PR #2342 exact head `570b874318bfe42406c6f46f51798baed8c89e48`; blocker comment `5547556953`; CI run `33928934236`, canonical child `101203371687`, aggregate `CI result` `101203476417`.
- `VERSION-BOOTSTRAP-001` / PR #2343 exact product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`; automatic CI run `33930830358`; canonical child `101208897330`; aggregate `CI result` `101209082820`; actual canonical-child checkout HEAD `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`. Status: `REVIEW-FAILED / PROVENANCE-ONLY`.
- Independent review PR #2344 head `b60b8e2483333db21ca6cea068b7a1be9c0f4851`; handoff comment `5547912758`; verdict `REVIEW-FAIL-VERSION-BOOTSTRAP-001`.

#2341/#2342/#2343/#2344 remain open/unmerged provenance unless a proper downstream owner acts later. This architecture round does not close, merge, rebase, retarget, or force-push them.

## Current atomic contract — authoritative latest

- Task: `../../management/tasks/TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001.md`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- ADR: `../../decisions/ADR-0014-event-aware-exact-head-checkout-gate.md`
- Handoff: `../../management/89-2026-09-05-M6-MAINSAFE-001-VERSION-EXACT-HEAD-架构诊断与执行交接.md`
- Failed predecessor task retained at `../../management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`.

## Current evidence order

1. fresh canonical main/control-plane/version readback;
2. **new** product PR from fresh main; implementation/config diff only `.github/workflows/ci.yml` + `mobile/ios/project.yml CURRENT_PROJECT_VERSION 28 -> 29`, plus task-specific TFI records;
3. automatic PR event canonical child; raw evidence actual checkout HEAD == final product head; unchanged canonical script runs afterwards; child SUCCESS + same-run required `CI result` SUCCESS;
4. independent code review on that exact final product head;
5. protected merge queue `merge_group`; raw evidence actual checkout HEAD == current merge-group SHA; unchanged canonical script runs afterwards; child SUCCESS + required `CI result` SUCCESS;
6. canonical-main readback of accepted event-aware topology, unchanged canonical script and iOS 29/29;
7. remaining MAINSAFE fixture/evidence prerequisites before any packaged test release.

Manual dispatch/rerun, skipped/neutral child, workflow metadata without actual HEAD proof, a synthetic PR merge used as product-head proof, different SHA, optional status, direct merge/bypass, historical green checks, or sibling green workflows cannot substitute for this order.
