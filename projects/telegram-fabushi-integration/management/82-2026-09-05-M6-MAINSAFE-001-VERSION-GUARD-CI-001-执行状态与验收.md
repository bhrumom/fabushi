# 82 — TFI-M6-MAINSAFE-001 VERSION-GUARD-CI-001 执行状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture source: `#2340@a514a396cc7f6c1a3a622aba54906d33c00c3e4b`
- Requirement / Acceptance: `M6-PM-VG-R01` / `M6-PM-VG-A01`
- Product/CI PR: `#2342`
- Current state: `EXECUTION-VERSION-GUARD-CI-001-BLOCKED / SCOPE-EXPANSION-REQUIRED / CANONICAL-DRIFT-PREVENTS-SELF-BOOTSTRAP`

## Scope and implementation state

| Gate | State | Evidence |
|---|---|---|
| canonical main reread | PASS | `dbf22b467d35c8af2a074896c355a41993c8c191` |
| branch lineage | PASS | fresh branch from canonical main; no #2340/#2341 branch reuse |
| implementation allowlist | PASS | only `.github/workflows/ci.yml` implementation change |
| existing classifier behavior | PRESERVED | classifier text/outputs unchanged |
| new child identity | IMPLEMENTED | `Canonical version contract` |
| canonical script implementation | REUSED / UNCHANGED | `.github/scripts/assert-native-electron-canonical.sh` |
| child skip bypass | PROHIBITED BY DESIGN | child unconditional; `CI result` requires exact `success` |
| no new action/dependency | PASS | existing `actions/checkout@v5`; existing classifier action untouched |
| local heavy validation | NOT RUN | by task rule |
| first exact-head child raw log | **FAIL / VALID BLOCKER EVIDENCE** | CI `33928830797`, job `101203055760` |
| first exact-head `CI result` binding | **FAIL / VALID TOPOLOGY EVIDENCE** | job `101203097569` reflects child failure |
| independent code review | NOT STARTED | blocked before review |
| protected merge/readback | NOT AUTHORIZED | blocked before review |

## Raw Actions findings

On PR #2342 first evidence head `f57fb7ddc72db0db31c7e5ae45d32c786b2bf455`:

- `Canonical version contract` job `101203055760` was executed, not skipped.
- Raw job log shows `Run bash .github/scripts/assert-native-electron-canonical.sh`.
- The unchanged script failed with `iOS build number drift: canonical=29 project=28`, exit code 1.
- `CI result` job `101203097569` then read `version_contract_result="failure"` and failed with `Canonical version contract failed: failure`.
- `Canonical architecture guardrails` job `101203073047` succeeded separately and is not used as version evidence.
- Frontend, Worker, MCP plugin contracts and Electron Feature Host jobs were skipped under the unchanged existing classifier.

This proves both required topology properties: the canonical child actually runs, and its failure propagates into the protected required aggregate. It also proves the task cannot achieve its frozen success acceptance from the current base without changing the known stale `mobile/ios/project.yml`, which is prohibited here.

## Stop rule applied

Canonical base already contains the known 29-vs-28 drift. Correcting that drift requires `mobile/ios/project.yml`, reserved for the separately frozen version-contract repair and outside this task's allowlist. Execution must not weaken/skip the guard, change the script, special-case the topology PR, or alter rulesets/workflows outside `ci.yml`.

Therefore this execution is **BLOCKED** and returns to architecture. Do not start code review, merge, VERSION-CONTRACT-002, test release or stable release.

No evidence substitution and no local build/test/rustfmt/clippy/E2E occurred.
