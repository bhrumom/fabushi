# TFI-M6-MAINSAFE-001 evidence index

This directory indexes durable evidence for the MAINSAFE post-main recovery. GitHub PR/Actions state remains authoritative for live facts.

## Architecture evidence

- `POSTMAIN-FAILURE-DIAGNOSIS-2026-09-05.md` — original exact-main failure decomposition.
- `VERSION-GUARD-BLOCKER-DIAGNOSIS-2026-09-05.md` — diagnosis that #2341 lacked the required canonical-version topology.
- `VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md` — authoritative latest dependency-cycle diagnosis; proves the split guard/version sequence cannot self-bootstrap and freezes the same-head bootstrap.

## Historical execution provenance

- `VERSION-CONTRACT-001` / PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`; execution blocker comment `5547296411`. The execution/evidence files live on the historical #2341 branch/PR and prove the exact one-value `mobile/ios/project.yml` 28 -> 29 patch plus the missing guard execution.
- `VERSION-GUARD-CI-001` / PR #2342 exact head `570b874318bfe42406c6f46f51798baed8c89e48`; blocker/architecture-return comment `5547556953`; CI run `33928934236`, canonical child `101203371687`, aggregate `CI result` `101203476417`. The execution/evidence files live on #2342 and prove child/aggregate topology plus the canonical=29/project=28 failure.

Neither historical PR is accepted implementation lineage. Both remain open/unmerged provenance until a fresh-main replacement bootstrap PR exists and records the relationship.

## Current atomic contract

- Task: `../../management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`
- Requirement / Acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`
- ADR: `../../decisions/ADR-0013-version-bootstrap-atomic-required-gate.md`
- Dated status/acceptance: `../../management/84-2026-09-05-M6-MAINSAFE-001-VERSION-BOOTSTRAP-循环诊断与原子重规划状态与验收.md`
- Dated changelog: `../../management/85-2026-09-05-M6-MAINSAFE-001-VERSION-BOOTSTRAP-循环诊断与原子重规划变更日志.md`

## Current evidence order

1. fresh canonical main/control-plane readback;
2. replacement bootstrap PR exact head with only `.github/workflows/ci.yml` + `mobile/ios/project.yml` 28->29 plus task-specific TFI records;
3. automatic PR-head canonical child executed/not-skipped/SUCCESS + same-head required `CI result` SUCCESS;
4. independent exact-head code review;
5. protected merge queue `merge_group` canonical child executed/SUCCESS + required `CI result` SUCCESS;
6. canonical-main readback of accepted topology, 29/29 version mirror, unchanged canonical script;
7. remaining MAINSAFE fixture/evidence prerequisites before test release.

Manual dispatch/rerun, skipped/neutral child, different SHA, optional status, direct merge/bypass, or historical PR success cannot substitute for this order.