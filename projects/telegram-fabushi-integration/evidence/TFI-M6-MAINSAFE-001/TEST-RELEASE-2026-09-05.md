# TFI-M6-MAINSAFE-001 — test-release evidence index — 2026-09-05

Status: `BLOCKED / REQUIRED-MAINSAFE-POST-MAIN-PREREQUISITES-NOT-SATISFIED`

## Frozen identities

| Item | Exact identity |
|---|---|
| reviewed product PR | `#2345` |
| reviewed product head | `9c46c1d8f030be390995cc78f321aac0d96b7f44` |
| pre-merge canonical main | `dbf22b467d35c8af2a074896c355a41993c8c191` |
| merge-group / accepted canonical main | `63e49b87d1ca5ad64d988e73769bf4a4ed796a19` |
| independent review | `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001` |
| review records PR | `#2346`, read OPEN |
| architecture records PR | `#2340`, read OPEN |

## Protected merge evidence

- Queue ref: `refs/heads/gh-readonly-queue/main/pr-2345-dbf22b467d35c8af2a074896c355a41993c8c191`
- Merge-group CI: https://github.com/bhrumom/fabushi/actions/runs/33939126976 — SUCCESS, attempt 1.
- Canonical version job: https://github.com/bhrumom/fabushi/actions/runs/33939126976/job/101232897597 — SUCCESS.
  - raw checkout ref/SHA: `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
  - raw proof: `event=merge_group expected_head=63e49b87d1ca5ad64d988e73769bf4a4ed796a19 actual_head=63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
  - unchanged command executed afterward: `bash .github/scripts/assert-native-electron-canonical.sh`
- Required aggregate: https://github.com/bhrumom/fabushi/actions/runs/33939126976/job/101233054947 — SUCCESS.
  - raw aggregate includes `version_contract_result=success` and success for every selected required sibling.
- PR merge/readback: https://github.com/bhrumom/fabushi/pull/2345 — merged `2026-09-05T02:29:10Z`, merge SHA `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`.

## Exact-main post-main observations

Automatic push workflows were triggered at exact canonical SHA `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, including:

- Electron desktop quality gate: run `33939200878`.
- Native mobile quality gate: run `33939200888`.
- Project portfolio governance: run `33939200880` — observed SUCCESS.
- Additional repository push/workflow_run automations are recorded only as observational exact-main evidence; none is treated as a substitute for the frozen packaged-test prerequisites.

Electron canonical workflow contains real post-main packaging and packaged Playwright journey steps, 90-day Electron diagnostics upload, package upload, host binary caching, Rust dependency caching and sccache reporting. Native canonical workflow contains Android emulator and iOS simulator user tests, but its report artifact retention is still 14 days in the exact-main workflow. This mismatch is one of the already frozen evidence-contract defects and is not waived.

## Required prerequisite set absent from canonical main

At exact canonical SHA `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, GitHub contents readback returned `404 Not Found` for each of:

- `management/tasks/TFI-M6-MAINSAFE-001-IOS-FIXTURE-001.md`
- `management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001.md`
- `management/tasks/TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001.md`

The authoritative definitions remain only in unmerged architecture records PR #2340, where all three are frozen/not-started prerequisites. Consequently no compliant evidence bundle can be declared complete for this exact-main test-release stage.

## Evidence completeness verdict

`REQUIRED-MAINSAFE-POST-MAIN-PREREQUISITES-NOT-SATISFIED / BLOCKED`.

No stable release was issued. No synthetic screenshot/video/trace/report is fabricated. Any automatic artifacts produced by exact-main Actions are retained as observed CI evidence only and cannot be promoted to test-release PASS until the prerequisite set lands on canonical main through its own implementation/review/protected-merge sequence.
