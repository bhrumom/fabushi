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
- Status: `EXECUTION-IN-PROGRESS / PR-HEAD-CI-PENDING`

## Frozen scope

Product allowlist contains exactly one semantic change:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29`.

Permitted additional writes are execution/evidence/status/acceptance/changelog records under `projects/telegram-fabushi-integration/**` only.

Explicitly prohibited: `app-version.json`, Android, other application source, tests, Electron, workflows, Cargo/dependencies, version-generation logic, root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated/old task records, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY/MAINSAFE-002/003.

Failure-stop rule: if any second product file or new semantic defect is required, stop as `SCOPE-EXPANSION-REQUIRED / BLOCKED` and return to architecture.

## Verified contract and implementation

Canonical `app-version.json` at the base declares `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`. Base `mobile/ios/project.yml` declared `MARKETING_VERSION: 1.2.22` and stale `CURRENT_PROJECT_VERSION: 28`.

`.github/scripts/assert-native-electron-canonical.sh` treats `app-version.json` as canonical and rejects any `CURRENT_PROJECT_VERSION` different from `iosBuildNumber`.

Implementation commit: `0e8f475f0cff2948f3e38beedc7af8440826ec8c`.
Implementation meaning: change only the XcodeGen iOS build-number mirror from 28 to 29, preserving the canonical source in `app-version.json` and restoring the expected CFBundleVersion/build-number contract.

## Open-source / official review

- Apple official bundle-version semantics: `CFBundleVersion` is the build-version identifier used for a build. Adopted only as the platform semantic authority; no external code copied.
- XcodeGen (`yonaskolb/XcodeGen`), MIT license: mature generator used to express Xcode build settings in YAML. The repository is actively maintained and `project.yml` is the appropriate generated-project specification surface. Adopted as design/context evidence only; no upstream code copied.
- Rejected: adding a new version dependency/tool or changing generator logic. This repair is a data-alignment change and introducing machinery would violate the frozen one-value scope.

## Verification policy

No local build/test/rustfmt/clippy/E2E was run. Local-equivalent activity was limited to GitHub file/diff/text inspection. Heavy validation is GitHub Actions on the exact PR head only; historical SHA results are not acceptance evidence.

## Pending closure for execution handoff

A new product PR will be opened from `fix/tfi-m6-mainsafe-001-version-contract-001` to `main`. Exact final PR head, changed-files readback, exact-head Actions runs/jobs, final execution records and review handoff comment will be appended before this execution session can become a PASS candidate.
