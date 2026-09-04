# TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001 — wire canonical version guard into required CI result

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VG-R01`
- Acceptance ID: `M6-PM-VG-A01`
- Status: `FROZEN / NOT_STARTED`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Blocked predecessor: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`

## Goal

Make every future pull request whose exact diff can change the canonical native/Electron version contract automatically execute `.github/scripts/assert-native-electron-canonical.sh` as a child gate of the protected required status `CI result`.

This task fixes CI/governance topology only. It does not modify the version value or any product behavior.

## Root-cause input

- `main-merge-queue` ruleset id `15857448` requires only `CI result`.
- existing `Canonical architecture guardrails` checks only retired Flutter/Tauri/Capacitor workflow commands and does not execute the canonical version script.
- current `CI result` has no version-contract child gate.
- Electron desktop invokes the script but its PR path filter does not cover `mobile/ios/project.yml`; Electron status is not the protected required status anyway.
- #2341 final head therefore has five green workflows but no canonical version-guard execution.

## Exact implementation allowlist

- `.github/workflows/ci.yml` only.

No other file may be changed in the implementation PR except TFI project records under `projects/telegram-fabushi-integration/**`.

## Required design

Within `ci.yml`:

1. extend impact classification with a dedicated boolean domain/output for the canonical version contract, selected by the minimum source set required by `.github/scripts/assert-native-electron-canonical.sh` to validate version drift, including at minimum:
   - `app-version.json`
   - `mobile/ios/project.yml`
   - `.github/scripts/assert-native-electron-canonical.sh`
   - version-bearing package/lock inputs that the script compares (`desktop/package.json`, `desktop/package-lock.json`, `mobile/package.json`, `mobile/package-lock.json`)
   - `ci.yml` itself for self-validation.
2. add a lightweight job with a truthful unique name such as `Canonical version contract`, sparse-checking out every file required by the existing script and executing exactly:
   - `bash .github/scripts/assert-native-electron-canonical.sh`
3. make `CI result` `needs` include this job and fail if a selected version-contract job does not succeed.
4. preserve existing PR/merge_group/push/workflow_dispatch behavior, unknown non-doc force-all safety, required status name `CI result`, and current merge-queue compatibility.
5. workflow-only PRs must still validate this topology; the guard may not become silently skipped when its own selector/aggregation is edited.

The existing script remains the single validation implementation. Do not duplicate or reimplement its version comparisons inline in YAML.

## Out of scope / prohibited

- no edit to `.github/scripts/assert-native-electron-canonical.sh`;
- no edit to `electron-desktop.yml`, `native-mobile.yml`, release workflows or rulesets in this task;
- no `mobile/ios/project.yml` or `app-version.json` change;
- no product/test source, Cargo/dependency, package version, build number or release change;
- no local build/test;
- do not rename/remove `CI result` or weaken its existing dependencies;
- do not replace the required aggregate with a separate optional status;
- do not rely on manual `workflow_dispatch` as closure evidence.

If `.github/workflows/ci.yml` alone cannot satisfy these requirements, STOP as `SCOPE-EXPANSION-REQUIRED` and return to architecture before touching any other workflow/ruleset.

## GitHub Actions exact-head acceptance

On the implementation PR exact head:

1. `CI` runs and includes a `Canonical version contract` job that is **executed, not skipped**, because `ci.yml` itself changed.
2. raw job steps/logs show checkout of the required canonical/version files and actual execution of `.github/scripts/assert-native-electron-canonical.sh`.
3. the job is SUCCESS and `CI result` is SUCCESS on the same exact head.
4. workflow/portfolio governance and other automatically applicable checks are green.
5. independent code review approves the exact implementation head.
6. protected merge queue validates `CI result`; no bypass/direct merge.
7. canonical `main` is read back after merge and the new `ci.yml` topology is verified there.

## Post-main prerequisite

Only after canonical readback may `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002` start from the new main. This CI task does not authorize review/merge of #2341 or any test/stable release.

## Open-source-first

- GitHub Actions official workflow/path-filter and required-check documentation: adopt automatic path selection + required latest-SHA evidence semantics; no code copied.
- GitHub manual workflow documentation: `workflow_dispatch` retained as diagnostic capability but rejected as a durable required PR-gate substitute.
- `actions/github-script` MIT: repository already uses it for impact classification; retain existing approach where useful, no upstream code copied.
- Fabushi FCM ADR-0005: preserve cheap deterministic PR gates, unknown-path fail-safe, aggregate `CI result`, merge queue and post-main heavy validation.
