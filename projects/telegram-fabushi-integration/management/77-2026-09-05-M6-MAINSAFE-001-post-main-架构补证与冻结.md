# TFI-M6-MAINSAFE-001 post-main 架构补证与冻结

日期：2026-09-05 (+08:00)

- Project: `FAB-P0001 / TFI`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture state: `POSTMAIN-FAILURE-DIAGNOSED / ATOMIC-TASKS-FROZEN`
- Execution / code review / test release / stable release: **PAUSED**
- Completed `OWNERSHIP-001`: remains completed; not restarted.
- `MAINSAFE-002/003`: **NOT STARTED**.

This checkpoint is the 2026-09-05 incremental governance write-back for milestone, acceptance, risk, dependency, status, changelog and issue/action tracking. It does not replace older historical ledgers; where older #2339 iOS facts conflict, the new raw-evidence diagnosis is authoritative for this failure.

## Milestone update

M6-MAINSAFE post-main closure is **BLOCKED** until four independently frozen tasks complete their own implementation -> independent review -> protected-main merge queue -> canonical readback gates, followed by a new exact-main packaged/native acceptance round:

1. `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001`
2. `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`
3. `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001`
4. `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001`

No milestone promotion may be inferred from the prior macOS/Windows/Android successes because Linux packaged, native iOS, and evidence completeness are required together.

## Acceptance update

| Gate | Current evidence | State | Exit condition |
|---|---|---|---|
| protected OWNERSHIP-001 product merge | #2336 -> `dbf22b...` | PASS / historical | do not reopen |
| iOS exact-main deterministic UI bootstrap | run 33920502967 / job 101177474816 | FAIL | IOS-FIXTURE-001 merged + new exact-main iOS green |
| canonical version mirror | app-version iOS=29 vs project=28 | FAIL | VERSION-CONTRACT-001 single-file fix merged + guard green |
| packaged/native evidence contract | Electron partial 90d; native 14d; screenshot failure-only; manifest incomplete | FAIL | EVIDENCE-CONTRACT-001 merged + pass/fail artifacts verified |
| OWNERSHIP-specific packaged journey | no dedicated complete journey found | FAIL | EVIDENCE-JOURNEY-001 merged + unweakened packaged journey green |
| new exact-main test release | not authorized | BLOCKED | all applicable gates green on one new canonical SHA |

Detailed acceptance record: `management/acceptance/TFI-M6-MAINSAFE-001-POSTMAIN-2026-09-05.md`.

## Risk update

- `RISK-M6-POSTMAIN-001` — **HIGH / ACTIVE**: native iOS deterministic test-mode auth/bootstrap may remain between onboarding and login/authenticated shell; release acceptance cannot prove downstream user journeys.
  - mitigation: IOS-FIXTURE-001 only; no route/assertion masking.
- `RISK-M6-POSTMAIN-002` — **HIGH / ACTIVE**: canonical iOS build counter and generated-project mirror disagree (29 vs 28), blocking Linux packaged architecture guard.
  - mitigation: VERSION-CONTRACT-001 strict one-file 28 -> 29.
- `RISK-M6-POSTMAIN-003` — **MEDIUM-HIGH / ACTIVE**: evidence gaps can create unverifiable pass/fail claims or confuse artifacts across run/journey/platform.
  - mitigation: EVIDENCE-CONTRACT-001 exact identity manifest/naming + failure-safe uploads + target 90 days.
- `RISK-M6-POSTMAIN-004` — **HIGH / ACTIVE**: broad packaged journeys can appear green while failing to prove OWNERSHIP-001's combined semantics.
  - mitigation: EVIDENCE-JOURNEY-001 dedicated journey; any semantic failure returns to architecture.
- `RISK-M6-POSTMAIN-005` — **HIGH / ACTIVE**: #2339 contains an incorrect iOS test name/failure description for run 33920502967.
  - mitigation: architecture evidence supersedes that claim; handoff comment must point downstream groups to exact raw evidence.

## Dependency / blocker update

- `DEP-M6-POSTMAIN-001`: IOS-FIXTURE-001 depends only on canonical `dbf22b...` raw failure evidence; independent of version/evidence tasks.
- `DEP-M6-POSTMAIN-002`: VERSION-CONTRACT-001 depends on canonical version source `app-version.json=29` and stale `project.yml=28`; independent of iOS fixture semantics.
- `DEP-M6-POSTMAIN-003`: EVIDENCE-CONTRACT-001 is prerequisite for final evidence-complete test-release acceptance.
- `DEP-M6-POSTMAIN-004`: EVIDENCE-JOURNEY-001 depends on completed OWNERSHIP-001 semantics and EVIDENCE-CONTRACT-001 plumbing.
- `BLK-M6-POSTMAIN-001`: test release/stable release remain blocked until all applicable tasks land on one new canonical main and a fresh exact-main acceptance round passes.
- `BLK-M6-POSTMAIN-002`: code review is not started by this architecture PR; each future execution task must receive its own independent review after implementation.

## Status update

Current architecture status is **READY-FOR-ONE-AT-A-TIME-EXECUTION-HANDOFF, but execution remains paused until this records-only architecture PR and #2339 handoff are written/read back**.

Recommended future execution ordering after handoff:

1. `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` — smallest isolated one-file repair and directly restores Linux packaged eligibility.
2. `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001` — independent native iOS acceptance repair.
3. `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001` — evidence plumbing.
4. `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` — only after evidence contract is available.

This ordering is not authorization to start multiple sessions in parallel. Start exactly one frozen execution task at a time unless a later architecture decision explicitly permits safe parallelism.

## Changelog update

- Re-read canonical main and #2339 exact base/head/changed records.
- Reconstructed run 33920502967/job 101177474816 from original Actions logs and downloaded xcresult 9955210308.
- Rejected stale DerivedData cache, wrong checkout, and artifact/report cross-wire as iOS causes.
- Corrected #2339's `testAccountSettingsAndMessagingFlow()` narrative: canonical source/xcresult contain the three current UI test methods and XCTest reports 5 executions / 4 failures because retries are counted.
- Diagnosed actual iOS failure at deterministic auth/bootstrap reachability before downstream product journeys.
- Verified PR #2318 version change and current project mirror drift; froze exact one-file version repair.
- Audited packaged/native artifact policies and froze evidence contract + dedicated OWNERSHIP journey.
- Recorded official/mature XCTest, GitHub Actions and Playwright sources/licenses with adopt/reject rationale; no external code copied.

## Issue / action update

- `ACT-M6-POSTMAIN-001` — execute VERSION-CONTRACT-001 only after architecture handoff; OPEN/FROZEN.
- `ACT-M6-POSTMAIN-002` — execute IOS-FIXTURE-001 only after architecture handoff; OPEN/FROZEN.
- `ACT-M6-POSTMAIN-003` — execute EVIDENCE-CONTRACT-001 only after earlier execution/review boundary; OPEN/FROZEN.
- `ACT-M6-POSTMAIN-004` — execute EVIDENCE-JOURNEY-001 only after evidence contract; OPEN/FROZEN.
- `ACT-M6-POSTMAIN-005` — after all required protected merges, start a new test-release session from the newly read-back canonical SHA; BLOCKED.

## Failure-stop policy

Any task that discovers a required file outside its allowlist, any new semantic product failure, or any mismatch between claimed and GitHub-observed SHA/run/artifact must stop and return to architecture. No assertion relaxation, bypass merge, direct main write, release shortcut, or scope expansion is permitted.
