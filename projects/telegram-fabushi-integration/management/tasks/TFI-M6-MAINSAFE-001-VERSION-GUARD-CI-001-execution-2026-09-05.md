# TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001 execution — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
- Architecture source: records-only PR `#2340@a514a396cc7f6c1a3a622aba54906d33c00c3e4b`
- Architecture handoff: PR #2341 comment `5547466413`
- Historical blocked predecessor: PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`, blocker comment `5547296411`
- Canonical base: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Requirement: `M6-PM-VG-R01`
- Acceptance: `M6-PM-VG-A01`
- Branch: `fix/tfi-m6-mainsafe-001-version-guard-ci-001`
- Initial implementation commit: `3aa3fac353671a2b7203f242ee12d1ff3119d345`
- Status: `IN_PROGRESS / AWAITING-EXACT-HEAD-ACTIONS`

## Frozen scope

Only implementation file allowed:

- `.github/workflows/ci.yml`

Additional writes are limited to this task's execution/evidence/status/changelog records under `projects/telegram-fabushi-integration/**`.

Explicitly prohibited: `.github/scripts/assert-native-electron-canonical.sh`, Electron/native/release workflows, rulesets/branch protection, `mobile/ios/project.yml`, `app-version.json`, Android/product/test source, Cargo/dependencies, version/release semantics, VERSION-CONTRACT-002, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY, OWNERSHIP-001, MAINSAFE-002/003.

## Implementation design

The implementation deliberately does **not** change the existing changed-path classifier. Adding a new classifier domain for version-bearing files would turn previously unknown non-doc paths into classified paths and could therefore reduce the existing fail-safe `forceAll` behavior. That would violate the task requirement to preserve unrelated CI behavior.

Instead `ci.yml` gains one lightweight, unconditional job named `Canonical version contract`:

1. checkout uses `actions/checkout@v5`, already used by the repository;
2. sparse checkout includes the existing canonical script plus every repository path that script directly reads/tests;
3. the job executes exactly `bash .github/scripts/assert-native-electron-canonical.sh`;
4. `CI result` adds this job to `needs` and explicitly requires `needs.canonical-version-contract.result == success` before applying the existing success-or-skipped policy to pre-existing diff-selected jobs.

This makes the version guard impossible to bypass via a skipped child while leaving existing domain selection unchanged. No version logic is duplicated in YAML and no new dependency/action is introduced.

## Open-source / official review

- GitHub Actions official workflow/job dependency and required-status documentation: adopted the principle that the required aggregate must depend on the real child gate and that merge-queue workflows must support `merge_group`; no code copied.
- GitHub Actions official manual-workflow documentation: `workflow_dispatch` remains diagnostic only and is rejected as acceptance evidence for this automatic PR gate.
- `actions/checkout`: GitHub-maintained action, MIT; already present in the repository and reused, no new dependency.
- `actions/github-script`: GitHub-maintained, MIT; existing classifier retained unchanged; no upstream code copied.
- Fabushi FCM ADR-0005: preserve cheap deterministic checks, aggregate `CI result`, merge queue, unknown-path fail-safe, and post-main heavy validation.

## Validation policy

No local build/test/rustfmt/clippy/E2E is run. Only GitHub diff/content inspection is used locally in the execution workflow; GitHub Actions is authoritative for the actual guard execution.

The current canonical base still has the known `app-version.json.iosBuildNumber=29` versus `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28` drift. Therefore this execution does not assume the new guard will be green on its own topology PR. If the exact-head job faithfully executes the existing script and fails on that pre-existing drift, this task must stop `SCOPE-EXPANSION-REQUIRED / BLOCKED`; execution may not modify the version file or weaken the guard to self-bootstrap.

## Acceptance pending

Before PASS-CANDIDATE:

- final exact-head `Canonical version contract` must execute, not skip;
- raw log must prove the canonical script actually ran;
- the child and same-head `CI result` must succeed;
- all applicable exact-head repository workflows/checks must succeed;
- changed-files must remain `.github/workflows/ci.yml` plus only TFI execution records.

Any failure requiring an out-of-allowlist change stops this task and returns to architecture.
