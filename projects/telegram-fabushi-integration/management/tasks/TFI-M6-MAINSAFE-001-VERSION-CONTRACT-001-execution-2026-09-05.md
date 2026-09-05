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
- Last fully green pre-blocker record head: `c0bc37f649fdb4bae78cdde456e8c129c287ee2f`
- Status: `EXECUTION-VERSION-CONTRACT-001-BLOCKED / REQUIRED-CANONICAL-VERSION-GUARD-NOT-RUN / SCOPE-EXPANSION-OR-MANUAL-DISPATCH-REQUIRED`

## Frozen scope

Product allowlist contains exactly one semantic change:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29`.

Permitted additional writes are execution/evidence/status/acceptance/changelog records under `projects/telegram-fabushi-integration/**` only.

Explicitly prohibited: `app-version.json`, Android, other application source, tests, Electron, workflows, Cargo/dependencies, version-generation logic, root `AGENTS.md`, `projects/PORTFOLIO.json`, unrelated/old task records, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY/MAINSAFE-002/003.

## Verified contract and implementation

Canonical `app-version.json` at the base declares `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`. Base `mobile/ios/project.yml` declared `MARKETING_VERSION: 1.2.22` and stale `CURRENT_PROJECT_VERSION: 28`.

`.github/scripts/assert-native-electron-canonical.sh` treats `app-version.json` as canonical and rejects any `CURRENT_PROJECT_VERSION` different from `iosBuildNumber`.

Implementation commit `0e8f475f0cff2948f3e38beedc7af8440826ec8c` changes only the XcodeGen iOS build-number mirror from 28 to 29. PR #2341 changed-files contain exactly one product file plus four TFI execution/governance records.

## Open-source / official review

- Apple official bundle-version semantics: `CFBundleVersion` is the build-version identifier used for a build. Adopted only as platform semantic authority; no external code copied.
- XcodeGen (`yonaskolb/XcodeGen`), MIT license: mature generator used to express Xcode build settings in YAML. Adopted as context evidence only; no upstream code copied.
- Rejected: adding a dependency/tool or changing generator/version logic because that exceeds the frozen one-value repair.

## GitHub Actions observed on exact head `c0bc37f649fdb4bae78cdde456e8c129c287ee2f`

All five workflows automatically attached to that exact head completed successfully:

- CI `33926458962` — SUCCESS; `Canonical architecture guardrails` job `101196051273` SUCCESS; `CI result` job `101196401829` SUCCESS.
- Project portfolio governance `33926458998` — SUCCESS; `Validate immutable Project IDs` job `101195944369` SUCCESS.
- Developer Fiat Commerce `33926459024` — SUCCESS; jobs `101195944453`, `101195944538`, `101195944609`, `101195944630`, `101195944672` SUCCESS.
- Native mobile quality gate `33926458965` — SUCCESS; `Native Android` `101195989397` and `Native mobile result` `101196153499` SUCCESS. Raw job logs show the PR fast path checked diff cleanliness, shared Rust formatting and native manifest existence, while Android/iOS heavy build and simulator/UI-test steps were skipped.
- Explicit automerge `33926459071` — SUCCESS; `Authorize green PRs for protected merge` job `101195944844` SUCCESS. PR remained open/unmerged because execution did not authorize merge.

## Blocking acceptance gap

Frozen acceptance item 2 requires the **current-head GitHub architecture/version guard** to pass. The observed `Canonical architecture guardrails` CI job does not run `.github/scripts/assert-native-electron-canonical.sh`; its only substantive contract step rejects retired Flutter/Tauri/Capacitor architecture. The Native mobile PR fast path also does not run that version script.

Repository inspection shows `.github/scripts/assert-native-electron-canonical.sh` is executed by Electron/release workflows, including the Electron desktop quality gate. However the Electron desktop pull-request path filters do not include `mobile/ios/project.yml`, so PR #2341 did not automatically trigger that guard. An all-workflows read for exact head `c0bc37f...` returned exactly five runs and no Electron/version-guard run.

The available GitHub execution connector can read/rerun existing workflow jobs but exposes no workflow-dispatch operation. Making the missing guard automatic would require a workflow/path change outside this task's allowlist; claiming the architecture-only CI job as the version guard would be false evidence.

Therefore execution stops here under the frozen failure-stop policy. No scope expansion, workflow modification, review handoff, merge, test release or stable release is performed. Architecture must decide either how to dispatch the existing canonical version guard on this product head without changing product scope, or freeze a separate governance/CI task to make that guard applicable.

No local build/test/rustfmt/clippy/E2E was run by this execution session.
