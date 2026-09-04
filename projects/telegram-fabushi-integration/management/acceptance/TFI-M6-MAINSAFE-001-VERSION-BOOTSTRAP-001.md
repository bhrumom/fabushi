# TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001 acceptance matrix

- Project: `FAB-P0001 / TFI`
- Requirement: `M6-PM-VB-R01`
- Acceptance: `M6-PM-VB-A01`
- Replacement PR: `#2343`
- Base: `dbf22b467d35c8af2a074896c355a41993c8c191`

| ID | Criterion | Execution evidence requirement | State before final-head Actions |
|---|---|---|---|
| VB-A01-01 | Fresh-main lineage | #2343 branch created from live canonical main, not from #2340/#2341/#2342 | PASS |
| VB-A01-02 | Implementation allowlist | only `.github/workflows/ci.yml`, `mobile/ios/project.yml` one-value repair, task-specific TFI records | PASS BY DIFF, recheck final head |
| VB-A01-03 | Canonical child exists | `Canonical version contract` automatic PR job | IMPLEMENTED / PENDING RUN |
| VB-A01-04 | Canonical script actually executes | log must show `bash .github/scripts/assert-native-electron-canonical.sh`; not skipped/neutral | PENDING RUN |
| VB-A01-05 | Canonical script succeeds | same exact final head child conclusion `success` | PENDING RUN |
| VB-A01-06 | Required aggregate binds child | `CI result.needs` includes canonical child and rejects non-success | IMPLEMENTED / PENDING RUN |
| VB-A01-07 | Required aggregate succeeds | same exact final head `CI result=success` | PENDING RUN |
| VB-A01-08 | Other required/applicable PR gates | Project portfolio governance, Developer Fiat Commerce, explicit PR/automerge gate and any other applicable gate truthful success | PENDING RUNS |
| VB-A01-09 | No bypass | no manual dispatch/rerun/different SHA/optional status/special case used as closure | ENFORCED |
| VB-A01-10 | Historical provenance | #2341/#2342 exact heads/comments preserved; neither merged/rebased/retargeted/force-pushed/closed here | PASS |
| VB-A01-11 | Independent review | separate code-review group reviews final exact head after execution pass | NOT STARTED / NEXT GATE |
| VB-A01-12 | Protected queue | later merge_group canonical child + CI result success | NOT STARTED / POST-REVIEW |
| VB-A01-13 | Canonical readback | later main proves 29/29 + accepted topology + unchanged script | NOT STARTED / POST-MERGE |

## Truth rule

This matrix never promotes a pending item from a historical or earlier SHA. The terminal PR-head execution verdict is determined only from GitHub live Actions attached to the final #2343 head after all execution records are committed. If the canonical child is missing, skipped, neutral, or non-success, the task is BLOCKED and returns to Architecture without scope expansion.
