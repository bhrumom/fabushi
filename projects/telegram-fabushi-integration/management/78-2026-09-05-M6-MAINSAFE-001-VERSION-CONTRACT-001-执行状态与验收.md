# 78 — TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 执行状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture: `#2340@b747096704af068a0aa4ee00f2de98073ea6165c`
- Product PR: `#2341`
- Acceptance ID: `M6-PM-A01`
- Current state: `EXECUTION-VERSION-CONTRACT-001-BLOCKED / REQUIRED-CANONICAL-VERSION-GUARD-NOT-RUN`

## Acceptance state

| Gate | Evidence | State |
|---|---|---|
| Frozen allowlist | only product file is `mobile/ios/project.yml`; all other PR files are TFI execution records | PASS |
| Canonical source | `app-version.json.iosBuildNumber=29` | PASS |
| Stale mirror identified | base `CURRENT_PROJECT_VERSION=28` | PASS |
| Minimal implementation | `0e8f475f0cff2948f3e38beedc7af8440826ec8c`, one-line 28 -> 29 | PASS |
| Exact-head changed-files | #2341 contained exactly 5 files at `c0bc37f...`: 1 product + 4 allowed records | PASS |
| Repository CI result | run `33926458962`; `CI result` `101196401829` | PASS |
| Architecture-only CI guard | `Canonical architecture guardrails` `101196051273` | PASS, but not the required version script |
| Canonical version guard script | `.github/scripts/assert-native-electron-canonical.sh` on current product head | **NOT RUN / BLOCKER** |
| Portfolio governance | `33926458998` / `101195944369` | PASS |
| Developer Fiat Commerce | `33926459024`; five jobs | PASS |
| Native mobile PR gate | `33926458965` / `101195989397` + `101196153499` | PASS; heavy platform steps skipped by PR fast-path |
| Explicit PR gate | `33926459071` / `101195944844` | PASS; no merge performed |
| Open-source/official review | Apple bundle-version semantics + XcodeGen MIT; no code copied | PASS |
| Local heavy validation | intentionally not run | N/A by task rule |
| Independent code review | not started | BLOCKED |
| Protected merge/main readback | not authorized | BLOCKED |

## Blocker proof

Frozen task acceptance item 2 requires the current-head GitHub architecture/version guard. The CI job named `Canonical architecture guardrails` does not execute `.github/scripts/assert-native-electron-canonical.sh`; its substantive check only rejects retired Flutter/Tauri/Capacitor architecture. Native mobile PR fast-path logs likewise do not execute that script.

The version script is wired into Electron/release workflows, but Electron desktop PR path filters do not include `mobile/ios/project.yml`, so #2341 did not trigger it. Exact-head all-runs readback returned only CI, portfolio governance, Developer Fiat Commerce, Native mobile quality gate and Explicit automerge.

The connected GitHub Actions interface in this execution session has no workflow-dispatch operation. Editing a workflow/path trigger is outside this atomic allowlist. Therefore execution cannot truthfully claim acceptance item 2 and must stop.

## Stop state

`SCOPE-EXPANSION-OR-MANUAL-DISPATCH-REQUIRED / BLOCKED`.

Do not start code review, merge, test release or stable release. Return to architecture to choose a compliant way to run the existing version guard on the product head or freeze a separate CI/governance task.
