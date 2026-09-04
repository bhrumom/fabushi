# 82 — TFI-M6-MAINSAFE-001 VERSION-GUARD-CI-001 执行状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture source: `#2340@a514a396cc7f6c1a3a622aba54906d33c00c3e4b`
- Requirement / Acceptance: `M6-PM-VG-R01` / `M6-PM-VG-A01`
- Current state: `IN_PROGRESS / AWAITING-FINAL-EXACT-HEAD-ACTIONS`

## Scope state

| Gate | State | Evidence |
|---|---|---|
| canonical main reread | PASS | `dbf22b467d35c8af2a074896c355a41993c8c191` |
| branch lineage | PASS | fresh branch from canonical main; no #2340/#2341 branch reuse |
| implementation allowlist | PASS so far | only `.github/workflows/ci.yml` implementation change |
| existing classifier behavior | PRESERVED | classifier text/outputs unchanged |
| new child identity | IMPLEMENTED | `Canonical version contract` |
| canonical script implementation | REUSED / UNCHANGED | `.github/scripts/assert-native-electron-canonical.sh` |
| child skip bypass | PROHIBITED BY DESIGN | child unconditional; `CI result` requires exact `success` |
| no new action/dependency | PASS | existing `actions/checkout@v5`; existing classifier action untouched |
| local heavy validation | NOT RUN | by task rule |
| exact-head child raw log | PENDING | GitHub Actions after PR creation |
| exact-head `CI result` | PENDING | GitHub Actions after PR creation |
| applicable repository checks | PENDING | GitHub Actions after PR creation |
| independent code review | NOT STARTED | execution cannot self-review |
| protected merge/readback | NOT AUTHORIZED | review phase only after PASS-CANDIDATE |

## Implementation choice

The child runs on every CI invocation rather than introducing a new changed-path classifier output. This preserves the current unknown-non-doc `forceAll` safety semantics and makes a future `mobile/ios/project.yml` change incapable of skipping the guard. The extra job is dependency-free apart from checkout and the repository's existing Bash/Python-stdlib script.

## Known bootstrap risk

Canonical base still contains the already diagnosed 29-vs-28 version drift. Therefore the new job may truthfully fail on this topology PR. If GitHub raw logs show that the unchanged canonical script executed and failed on that existing drift, execution must stop as `SCOPE-EXPANSION-REQUIRED / BLOCKED`: fixing the drift belongs to the separately frozen VERSION-CONTRACT-002 and is prohibited in this task.

No evidence substitution is permitted. A failing canonical child cannot be waived by successful architecture guardrails, Native mobile fast path, manual dispatch, or unrelated checks.
