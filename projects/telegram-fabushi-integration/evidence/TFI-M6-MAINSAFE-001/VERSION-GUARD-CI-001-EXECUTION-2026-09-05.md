# TFI-M6-MAINSAFE-001 VERSION-GUARD-CI-001 execution evidence — 2026-09-05

## Identity
- Project/task: `FAB-P0001 / TFI` / `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
- Canonical base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture PR/head: `#2340@a514a396cc7f6c1a3a622aba54906d33c00c3e4b`
- Historical blocked PR: `#2341@2241c856fb3da498ac99ade89007fe01dd335183`
- Architecture handoff: #2341 comment `5547466413`
- Execution branch: `fix/tfi-m6-mainsafe-001-version-guard-ci-001`
- Initial implementation commit: `3aa3fac353671a2b7203f242ee12d1ff3119d345`
- Acceptance: `M6-PM-VG-A01`

## Baseline proof
- Live canonical main was re-read before branch creation and remained `dbf22b467d35c8af2a074896c355a41993c8c191`.
- Ruleset `15857448` requires only `CI result` and has no bypass actor.
- Existing `CI result` had no version-contract child dependency.
- Existing `Canonical architecture guardrails` only checks retired Flutter/Tauri/Capacitor workflow commands.
- Existing authoritative version script is `.github/scripts/assert-native-electron-canonical.sh`.

## Implementation proof

Initial compare `dbf22b... -> 3aa3fac...` changed exactly one file, `.github/workflows/ci.yml`, with 42 additions and no deletions.

The implementation adds `Canonical version contract` as an unconditional lightweight job and adds it to the protected aggregate's dependency list. The aggregate explicitly rejects every result other than `success` for this child, so a skipped child cannot satisfy `CI result`.

The job sparse-checks out all direct inputs required by the unchanged canonical script and runs exactly:

`bash .github/scripts/assert-native-electron-canonical.sh`

No version assertion is copied into YAML and no new action/dependency is introduced.

## Why unconditional instead of a new classifier domain

A new version domain would make version-bearing paths count as already classified. On current `ci.yml`, unknown non-doc paths deliberately force all canonical domains. Reclassifying those paths could therefore reduce pre-existing safety behavior. Running this dependency-free guard on every CI event is the smaller semantic change and guarantees a future `mobile/ios/project.yml` PR cannot skip the child.

## Open-source / official provenance

- GitHub Actions official documentation: job `needs`, required status checks, merge queue / `merge_group`, and manual workflows. Adopted semantics only; no copied code.
- `actions/checkout` — GitHub-maintained, MIT; existing repository dependency reused.
- `actions/github-script` — GitHub-maintained, MIT; existing classifier remains unchanged.
- Fabushi FCM ADR-0005 — retained cheap deterministic required gates and aggregate `CI result` while preserving post-main heavy validation.

## Validation pending

GitHub Actions exact-head run/job IDs, raw-log lines, conclusions, final changed-files, and final stop/pass state will be appended in the task status records after the PR's final exact head completes.

No local build/test/rustfmt/clippy/E2E is used as acceptance evidence.
