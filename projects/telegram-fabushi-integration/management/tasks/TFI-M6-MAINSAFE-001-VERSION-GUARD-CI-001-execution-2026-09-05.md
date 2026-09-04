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
- Product/CI PR: `#2342`
- Initial implementation commit: `3aa3fac353671a2b7203f242ee12d1ff3119d345`
- First PR evidence head: `f57fb7ddc72db0db31c7e5ae45d32c786b2bf455`
- Status: `EXECUTION-VERSION-GUARD-CI-001-BLOCKED / SCOPE-EXPANSION-REQUIRED / CANONICAL-DRIFT-PREVENTS-SELF-BOOTSTRAP`

## Frozen scope

Only implementation file allowed:

- `.github/workflows/ci.yml`

Additional writes are limited to this task's execution/evidence/status/changelog records under `projects/telegram-fabushi-integration/**`.

Explicitly prohibited: `.github/scripts/assert-native-electron-canonical.sh`, Electron/native/release workflows, rulesets/branch protection, `mobile/ios/project.yml`, `app-version.json`, Android/product/test source, Cargo/dependencies, version/release semantics, VERSION-CONTRACT-002, IOS-FIXTURE/EVIDENCE-CONTRACT/EVIDENCE-JOURNEY, OWNERSHIP-001, MAINSAFE-002/003.

## Implementation design

The implementation deliberately does **not** change the existing changed-path classifier. Adding a new classifier domain for version-bearing files would turn previously unknown non-doc paths into classified paths and could reduce the existing fail-safe `forceAll` behavior.

Instead `ci.yml` gains one lightweight, unconditional job named `Canonical version contract`:

1. checkout uses existing `actions/checkout@v5`;
2. sparse checkout includes the unchanged canonical script plus every path it directly reads/tests;
3. the job executes exactly `bash .github/scripts/assert-native-electron-canonical.sh`;
4. `CI result` adds the child to `needs` and explicitly requires `needs.canonical-version-contract.result == success` before applying the existing success-or-skipped policy to prior diff-selected jobs.

Thus the child cannot be bypassed by `skipped`, version logic is not duplicated, and no new action/dependency is introduced.

## Open-source / official review

- GitHub Actions official workflow/job dependency and required-status documentation: adopted the principle that the required aggregate must depend on the real child gate and merge-queue workflows must support `merge_group`; no code copied.
- GitHub Actions official manual-workflow documentation: `workflow_dispatch` remains diagnostic only and is rejected as automatic-gate acceptance evidence.
- `actions/checkout`: GitHub-maintained, MIT; already present and reused.
- `actions/github-script`: GitHub-maintained, MIT; existing classifier retained unchanged; no upstream code copied.
- Fabushi FCM ADR-0005: preserve cheap deterministic checks, aggregate `CI result`, merge queue, unknown-path fail-safe, and post-main heavy validation.

## First exact-head GitHub Actions evidence

PR #2342 first evidence head `f57fb7ddc72db0db31c7e5ae45d32c786b2bf455` triggered CI run `33928830797`.

- `Classify CI changes` job `101203055701`: SUCCESS.
- `Canonical version contract` job `101203055760`: **FAILURE**, and it was actually executed, not skipped.
- Raw child log proves checkout of the canonical version inputs and then exactly:
  - `Run bash .github/scripts/assert-native-electron-canonical.sh`
  - `iOS build number drift: canonical=29 project=28`
  - process exit code `1`.
- `Canonical architecture guardrails` job `101203073047`: SUCCESS; still only the retired Flutter/Tauri/Capacitor guard.
- Frontend/Worker/MCP/Electron Feature Host jobs: SKIPPED by the existing classifier, as expected for this workflow-only change.
- `CI result` job `101203097569`: **FAILURE**. Its raw log contains `version_contract_result="failure"` and `Canonical version contract failed: failure`, proving the protected aggregate waits for and reflects the new child.

This is positive proof that the requested CI topology works, but the task cannot satisfy the frozen requirement that the same exact-head child and `CI result` are SUCCESS because canonical main itself still contains the pre-existing 29/28 drift.

## Stop decision

Fixing the drift requires changing `mobile/ios/project.yml`, which is explicitly prohibited and belongs to the separately frozen VERSION-CONTRACT repair. Weakening/skipping the child, changing the canonical script, or special-casing this PR would violate the task contract.

Therefore execution stops as:

`SCOPE-EXPANSION-REQUIRED / BLOCKED`.

No code review, merge, VERSION-CONTRACT-002, test release or stable release is authorized. Return to architecture to resolve the bootstrap dependency between the new required guard and the already-known version drift.

No local build/test/rustfmt/clippy/E2E was run.
