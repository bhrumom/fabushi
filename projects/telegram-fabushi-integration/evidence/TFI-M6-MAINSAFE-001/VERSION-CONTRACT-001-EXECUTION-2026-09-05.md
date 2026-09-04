# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 execution evidence — 2026-09-05

## Identity
- Project/task: `FAB-P0001 / TFI` / `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001`.
- Canonical base: `dbf22b467d35c8af2a074896c355a41993c8c191`.
- Architecture PR/head: `#2340@b747096704af068a0aa4ee00f2de98073ea6165c`.
- Architecture handoff: `#2339` comment `5547183136`.
- Acceptance: `M6-PM-A01`.

## Source evidence
- Canonical `app-version.json`: `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`.
- Base `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28`.
- Canonical guard `.github/scripts/assert-native-electron-canonical.sh` requires `CURRENT_PROJECT_VERSION == app-version.json.iosBuildNumber`.

## Implementation evidence
- Branch: `fix/tfi-m6-mainsafe-001-version-contract-001` created directly from canonical base.
- Product implementation commit: `0e8f475f0cff2948f3e38beedc7af8440826ec8c`.
- Product diff: exactly `mobile/ios/project.yml`, `CURRENT_PROJECT_VERSION: 28` -> `29`.
- No `app-version.json`, Android, application/test/workflow/Cargo/dependency/version-generation changes were made.

## Open-source / official evidence
- Apple official bundle metadata semantics are the authority for iOS build-version meaning (`CFBundleVersion`). No code copied.
- XcodeGen `yonaskolb/XcodeGen` is a mature Swift Xcode project generator under MIT; its YAML project specification is the relevant upstream model for this repository's `project.yml`. No code copied.
- No new dependency or tool was adopted because the defect is a one-value mirror drift and any machinery would exceed the frozen scope.

## Verification boundary
- No local build/test/rustfmt/clippy/E2E.
- Only repository text/diff/state inspection before PR.
- Exact-head GitHub Actions evidence is pending and will be recorded here before handoff.
