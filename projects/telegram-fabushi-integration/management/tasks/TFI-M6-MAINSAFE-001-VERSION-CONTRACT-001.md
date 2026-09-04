# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 — canonical iOS build-number mirror repair

- Project: `FAB-P0001 / TFI`
- Status: `FROZEN / NOT_STARTED`
- Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Parent boundary: `TFI-M6-MAINSAFE-001`; do not reopen `OWNERSHIP-001`; do not start `MAINSAFE-002/003`.

## Evidence

- `app-version.json` is canonical and declares version `1.2.22`, Android version code `29`, iOS build number `29`.
- PR #2318 intentionally changed only `app-version.json` from Android/iOS build 28 to 29 and merged through protected main as `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- `mobile/ios/project.yml` on current canonical main still declares `CURRENT_PROJECT_VERSION: 28`.
- `.github/scripts/assert-native-electron-canonical.sh` requires the iOS project `CURRENT_PROJECT_VERSION` to equal `app-version.json.iosBuildNumber` and is the source of the exact-main Linux packaged failure.
- `.github/workflows/native-electron-release.yml` reads the release iOS build number from `app-version.json`; therefore the current project file is a stale generated-project mirror, not a new canonical version source.

## Single-file allowlist

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29` only.

## Prohibited

- do not edit `app-version.json`;
- do not edit Android version code, desktop/mobile package versions, application source, tests, workflows, Cargo/dependency, release tag/version semantics, or any other project setting;
- no local build/test.

If any additional file is claimed necessary, STOP and return to architecture rather than expanding this task.

## Acceptance

1. Exact diff is one file and one semantic value: `mobile/ios/project.yml` build 28 -> 29.
2. Current-head GitHub architecture/version guard passes.
3. Relevant current-head platform checks pass without unrelated changes.
4. Independent code review passes the exact head.
5. Protected merge queue only; no direct merge/bypass.
6. Canonical main readback proves `app-version.json.iosBuildNumber=29` and `project.yml CURRENT_PROJECT_VERSION=29`.
7. A new exact-main packaged test-release round must re-run Linux/desktop/native gates; this task alone does not authorize test or stable release.
