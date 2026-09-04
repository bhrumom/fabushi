# ADR-0013 — Atomic bootstrap for canonical version required gate

- Status: Accepted
- Date: 2026-09-05
- Project: `FAB-P0001 / TFI`
- Decision owner: Architecture
- Related task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Evidence: `../evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`

## Context

Canonical `main@dbf22b467d35c8af2a074896c355a41993c8c191` contains a pre-existing iOS version mirror drift: `app-version.json.iosBuildNumber=29` while `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28`.

Two protected-main attempts reveal a bootstrap cycle:

- historical version-only PR #2341 changes only `mobile/ios/project.yml` 28 -> 29, but its base does not contain the canonical-version child inside required `CI result`; therefore its green checks cannot prove the frozen current-head guard requirement;
- historical guard-only PR #2342 adds the canonical-version child to `CI result`, and exact-head CI proves that topology works, but the unchanged canonical script truthfully fails on the pre-existing 29/28 drift, which makes required `CI result` fail and prevents the guard-only PR from entering protected main.

The active `main-merge-queue` ruleset requires exactly `CI result`, has no bypass actor, and validates merge-queue heads. The repository canonical script already expresses the required version contract and is not defective by available evidence.

## Decision

When this specific pre-existing drift and missing required-gate topology coexist, bootstrap them as **one atomic protected transaction on one fresh-main exact head**.

The only implementation/config files allowed in that bootstrap PR are:

1. `.github/workflows/ci.yml` — add/preserve the already-proven canonical version-contract child and bind it to required `CI result` without duplicating version logic;
2. `mobile/ios/project.yml` — change only `CURRENT_PROJECT_VERSION: 28` -> `29`.

Task-specific records may be written only under `projects/telegram-fabushi-integration/**`.

The same exact head must automatically run the unchanged `.github/scripts/assert-native-electron-canonical.sh`; the child must execute rather than skip and must succeed; the same-head `CI result` must succeed. Independent review follows. The protected merge queue must then produce `merge_group` evidence where the same child executes/succeeds and required `CI result` succeeds before merge. Canonical `main` must be read back after merge to prove both topology and version mirror landed together.

This is a narrowly scoped bootstrap decision, not a general permission to combine unrelated CI and product work.

## Invariants

- `.github/scripts/assert-native-electron-canonical.sh` remains the single authority and is not edited.
- No version comparisons are duplicated into YAML or another script.
- Required status name `CI result`, merge queue behavior, `merge_group` handling, and existing CI domains are preserved.
- `skipped`, `neutral`, manual `workflow_dispatch`, rerun-only, earlier-SHA, optional-status, or bypass evidence cannot satisfy closure.
- Rulesets/branch protection, other workflows, `app-version.json`, Android, application/test source, Cargo/dependencies, and release controls remain outside scope.
- Any need to widen beyond the two implementation/config files returns to Architecture.

## Historical PR disposition

#2341 and #2342 are retained as historical evidence of the two halves of the cycle. Neither is a replacement lineage and neither may be merged, rebased, retargeted, or force-pushed to escape the new gate.

Only after a fresh-main replacement bootstrap PR exists and explicitly records provenance to #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`, #2342 exact head `570b874318bfe42406c6f46f51798baed8c89e48`, and blocker comments `5547296411` / `5547556953`, may the appropriate execution/product owner close the historical PRs as superseded.

## Alternatives rejected

- **Guard-only first, version-only second:** disproved by #2342 because truthful guard failure blocks the first protected merge.
- **Version-only first:** rejected because #2341 cannot meet the frozen required current-head canonical-script evidence.
- **Manual dispatch/rerun:** diagnostic only, not durable protected topology or merge-group evidence.
- **Allow skipped/special-case bootstrap:** creates the precise bypass the guard is intended to prevent.
- **Modify ruleset or branch protection:** broader control-plane change and unnecessary.
- **Modify canonical script:** no script defect is demonstrated.
- **Inline/duplicate version logic in CI YAML:** violates single-authority design.

## Open-source-first / provenance

Adopted official GitHub semantics, with no external code copied:

- workflow job dependencies via `jobs.<job_id>.needs`;
- job results via `needs.<job_id>.result`;
- required status checks bound to the relevant latest head;
- GitHub Actions merge-queue validation through the `merge_group` event.

Relevant official documentation:

- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- https://docs.github.com/en/actions/reference/workflows-and-actions/contexts
- https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets

Repository/open-source dependencies retained rather than invented:

- `actions/checkout` — MIT; already used by repository.
- `actions/github-script` — MIT; existing CI classifier dependency; no new dependency.
- Fabushi FCM ADR-0005 — preserve cheap deterministic gates, aggregate `CI result`, merge queue, and post-main heavy validation.

## Consequences

The bootstrap PR can become green without weakening truth: the value drift is removed on the same head where the required guard becomes authoritative. Future heads are then protected by the same canonical child. Historical split tasks are superseded, downstream review/test/release remains paused until the bootstrap and remaining MAINSAFE prerequisites complete.