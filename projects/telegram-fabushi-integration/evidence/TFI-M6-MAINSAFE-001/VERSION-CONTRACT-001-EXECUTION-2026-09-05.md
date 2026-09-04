# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 execution evidence — 2026-09-05

## Identity
- Project/task: `FAB-P0001 / TFI` / `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`.
- Canonical base: `dbf22b467d35c8af2a074896c355a41993c8c191`.
- Architecture PR/head: `#2340@b747096704af068a0aa4ee00f2de98073ea6165c`.
- Architecture handoff: `#2339` comment `5547183136`.
- Acceptance: `M6-PM-A01`.
- Product PR: `#2341`.
- Execution state: `BLOCKED / REQUIRED-CANONICAL-VERSION-GUARD-NOT-RUN`.

## Source and implementation evidence
- Canonical `app-version.json`: `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`.
- Base `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28`.
- Canonical guard `.github/scripts/assert-native-electron-canonical.sh` requires `CURRENT_PROJECT_VERSION == app-version.json.iosBuildNumber`.
- Branch `fix/tfi-m6-mainsafe-001-version-contract-001` was created directly from canonical base.
- Product implementation commit `0e8f475f0cff2948f3e38beedc7af8440826ec8c` changes exactly `mobile/ios/project.yml`, `CURRENT_PROJECT_VERSION: 28` -> `29`.
- No `app-version.json`, Android, other application/test/workflow/Cargo/dependency/version-generation product change was made.

## Open-source / official evidence
- Apple official bundle metadata semantics are the authority for iOS build-version meaning (`CFBundleVersion`). No code copied.
- XcodeGen `yonaskolb/XcodeGen` is a mature Swift Xcode project generator under MIT; its YAML project specification is the relevant upstream model for this repository's `project.yml`. No code copied.
- No new dependency/tool was adopted.

## Exact-head GitHub Actions evidence before blocker write-back

Exact product/record head `c0bc37f649fdb4bae78cdde456e8c129c287ee2f` had exactly five workflow runs, all successful:

- CI `33926458962`: SUCCESS; `Canonical architecture guardrails` `101196051273` and `CI result` `101196401829` SUCCESS.
- Project portfolio governance `33926458998`: SUCCESS; `Validate immutable Project IDs` `101195944369` SUCCESS.
- Developer Fiat Commerce `33926459024`: SUCCESS; jobs `101195944453`, `101195944538`, `101195944609`, `101195944630`, `101195944672` SUCCESS.
- Native mobile quality gate `33926458965`: SUCCESS; `Native Android` `101195989397`, `Native mobile result` `101196153499` SUCCESS. Raw logs prove PR fast-path checks ran and heavyweight Android/iOS build/simulator/UI-test steps were skipped.
- Explicit automerge `33926459071`: SUCCESS; `Authorize green PRs for protected merge` `101195944844` SUCCESS. PR remained open/unmerged.

## Required guard gap

Frozen acceptance item 2 requires a **current-head GitHub architecture/version guard**. The successful CI job named `Canonical architecture guardrails` does not execute `.github/scripts/assert-native-electron-canonical.sh`; its substantive guard step only rejects retired Flutter/Tauri/Capacitor architecture. The Native mobile PR fast path likewise does not run the version script.

Repository workflow inspection shows the canonical version script runs in Electron/release workflows, but Electron desktop pull-request path filters do not include `mobile/ios/project.yml`. The all-runs API for `c0bc37f...` returned exactly the five runs above, with no Electron/version-guard run.

The connected GitHub Actions capability available to this execution can read and rerun existing jobs but cannot dispatch a workflow. Editing workflow paths would exceed the frozen product allowlist. Therefore there is no truthful exact-head GitHub evidence that the required version guard itself ran.

## Stop decision

`SCOPE-EXPANSION-OR-MANUAL-DISPATCH-REQUIRED / BLOCKED`.

No review handoff, merge, test release or stable release is authorized. Architecture must decide how to run the existing canonical version guard on the product head without widening this task, or freeze a separate CI/governance repair.

No local build/test/rustfmt/clippy/E2E was run by this execution session.
