# 78 — TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 执行状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture: `#2340@b747096704af068a0aa4ee00f2de98073ea6165c`
- Acceptance ID: `M6-PM-A01`
- Current state: `EXECUTION-IN-PROGRESS / PR-HEAD-CI-PENDING`

## Acceptance state

| Gate | Evidence | State |
|---|---|---|
| Frozen allowlist | only product file allowed is `mobile/ios/project.yml` | PASS |
| Canonical source | `app-version.json.iosBuildNumber=29` | PASS |
| Stale mirror identified | base `CURRENT_PROJECT_VERSION=28` | PASS |
| Minimal implementation | commit `0e8f475f0cff2948f3e38beedc7af8440826ec8c` changes 28 -> 29 only | PASS |
| Open-source/official review | Apple bundle-version semantics + XcodeGen MIT; no code copied | PASS |
| Local heavy validation | intentionally not run | N/A by task rule |
| Exact-head Actions | pending new product PR | PENDING |
| Independent code review | not started | BLOCKED until execution handoff |
| Protected merge/main readback | not authorized in execution session | BLOCKED |

## Scope protection

No changes are permitted to `app-version.json`, Android, any other application source, test source, Electron, workflows, Cargo/dependencies, version generation, root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated old task records, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY/MAINSAFE-002/003.

If final PR changed-files or Actions prove otherwise, this task becomes `SCOPE-EXPANSION-REQUIRED / BLOCKED`.
