# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002 — superseded pre-execution plan

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VR-R02`
- Acceptance ID: `M6-PM-VR-A02`
- Status: `SUPERSEDED-BEFORE-EXECUTION / DO-NOT-START`
- Historical predecessor: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / PR #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`
- Historical guard-only attempt: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` / PR #2342 exact head `570b874318bfe42406c6f46f51798baed8c89e48`
- Superseding task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Superseding Requirement / Acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`

## Why this task is superseded

This task assumed the guard-only task could first be reviewed, protected-merged, and read back from canonical main. #2342 disproved that assumption: the newly wired canonical child truthfully executes on the current canonical baseline and fails because `app-version.json.iosBuildNumber=29` while `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28`; the required aggregate `CI result` propagates that failure.

Therefore the old two-step order cannot self-bootstrap. Running this version-only task separately before the guard would reproduce #2341's opposite deficiency: the frozen required canonical-version child would not exist on its base.

## Historical intended patch

The one semantic product/config repair remains valid evidence and is folded unchanged into the superseding bootstrap task:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29` only.

It is no longer authorized as a separate execution PR.

## Current disposition

Do not create a `VERSION-CONTRACT-002` implementation branch or PR. Do not use it to continue/review/merge #2341. Do not edit `.github/**` or any product/config file under this historical task.

The only next executable task is `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`, whose exact implementation/config allowlist is `.github/workflows/ci.yml` plus the same one-value `mobile/ios/project.yml` repair, on one fresh-main exact head.

## Historical invariants retained by the bootstrap

- `app-version.json` remains canonical and unchanged;
- Android version/code, package versions, application/test source, Cargo/dependencies, release/version-generation logic remain out of scope;
- canonical assertion script remains unchanged and is not duplicated;
- automatic exact-head canonical child + required `CI result`, independent review, protected merge queue `merge_group`, and canonical-main readback remain mandatory;
- manual dispatch/rerun/skipped/different-head evidence cannot substitute.

## Historical PR disposition

#2341 and #2342 remain open/unmerged provenance until a fresh-main bootstrap replacement PR exists and records both exact heads plus blocker comments `5547296411` / `5547556953`. Only then may the appropriate execution/product owner close them as superseded. Neither historical PR may be merged/rebased/retargeted/force-pushed as a shortcut.

## Superseding records

- `management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`
- `evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`
- `decisions/ADR-0013-version-bootstrap-atomic-required-gate.md`
