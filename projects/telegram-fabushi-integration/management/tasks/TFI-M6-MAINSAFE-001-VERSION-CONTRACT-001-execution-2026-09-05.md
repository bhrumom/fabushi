# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 execution — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`
- Architecture source: records-only PR `#2340@b747096704af068a0aa4ee00f2de98073ea6165c`
- Architecture handoff: PR `#2339` comment `5547183136`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Source acceptance: `M6-PM-A01`
- Source dependency: `DEP-M6-POSTMAIN-002`
- Source risk: `RISK-M6-POSTMAIN-002`
- Source action: `ACT-M6-POSTMAIN-001`
- Product PR: `#2341`
- Product implementation commit: `0e8f475f0cff2948f3e38beedc7af8440826ec8c`
- Validated record head before final evidence write-back: `0d852fd1ba2a663a4a90145c1956a3ff52b289ab`
- Status: `EXECUTION-PASS-CANDIDATE-PENDING-FINAL-RECORD-HEAD-REVALIDATION`

## Frozen scope

Product allowlist contains exactly one semantic change:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29`.

Permitted additional writes are execution/evidence/status/acceptance/changelog records under `projects/telegram-fabushi-integration/**` only.

Explicitly prohibited: `app-version.json`, Android, other application source, tests, Electron, workflows, Cargo/dependencies, version-generation logic, root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated/old task records, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY/MAINSAFE-002/003.

Failure-stop rule: if any second product file or new semantic defect is required, stop as `SCOPE-EXPANSION-REQUIRED / BLOCKED` and return to architecture.

## Verified contract and implementation

Canonical `app-version.json` at the base declares `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`. Base `mobile/ios/project.yml` declared `MARKETING_VERSION: 1.2.22` and stale `CURRENT_PROJECT_VERSION: 28`.

`.github/scripts/assert-native-electron-canonical.sh` treats `app-version.json` as canonical and rejects any `CURRENT_PROJECT_VERSION` different from `iosBuildNumber`.

Implementation commit `0e8f475f0cff2948f3e38beedc7af8440826ec8c` changes only the XcodeGen iOS build-number mirror from 28 to 29, preserving the canonical source in `app-version.json` and restoring the expected CFBundleVersion/build-number contract.

PR #2341 changed-files readback at head `0d852fd1ba2a663a4a90145c1956a3ff52b289ab` contained exactly five files: the one allowed product file plus four execution/governance records under `projects/telegram-fabushi-integration/**`. The product patch is exactly one line, 28 -> 29.

## Open-source / official review

- Apple official bundle-version semantics: `CFBundleVersion` is the build-version identifier used for a build. Adopted only as the platform semantic authority; no external code copied.
- XcodeGen (`yonaskolb/XcodeGen`), MIT license: mature generator used to express Xcode build settings in YAML. Adopted as design/context evidence only; no upstream code copied.
- Rejected: adding a new version dependency/tool or changing generator logic. This repair is a data-alignment change and introducing machinery would violate the frozen one-value scope.

## Exact-head GitHub validation already completed

Validated head: `0d852fd1ba2a663a4a90145c1956a3ff52b289ab`.

- CI run `33926299157` — SUCCESS. Included `Canonical architecture guardrails` job `101195472470` SUCCESS and the repository CI result path; all jobs completed successfully.
- Project portfolio governance run `33926299211` — SUCCESS; `Validate immutable Project IDs` job `101195446591` SUCCESS.
- Developer Fiat Commerce run `33926299246` — SUCCESS; all five jobs completed successfully.
- Native mobile quality gate run `33926299245` — SUCCESS; `Native Android` PR-fast-path job `101195446851` SUCCESS and `Native mobile result` job `101195590840` SUCCESS. The workflow correctly skipped heavy Android/iOS build/UI-test steps for this PR path classification; no skipped test is represented as executed evidence.

No local build/test/rustfmt/clippy/E2E was run. Historical SHA results were not reused.

## Final-head rule

This evidence write-back changes the PR head. Therefore the new final record head must itself receive fresh GitHub Actions validation before review handoff. Final exact-head run/job IDs and the immutable handoff comment will be recorded in the PR conversation without changing the head again. No merge, test release, or stable release is authorized by this execution session.
