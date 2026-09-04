# TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001 — atomic required-gate + iOS mirror bootstrap

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VB-R01`
- Acceptance ID: `M6-PM-VB-A01`
- Status: `FROZEN / NEXT-ONLY-EXECUTABLE`
- Architecture baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Historical product-only predecessor: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / PR #2341 @ `2241c856fb3da498ac99ade89007fe01dd335183`
- Historical guard-only predecessor: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` / PR #2342 @ `570b874318bfe42406c6f46f51798baed8c89e48`
- Architecture evidence: `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`

## Goal

Break the proven bootstrap dependency cycle in one protected, same-exact-head transaction: install the already-proven canonical version-contract child into required `CI result` **and** repair the already-proven stale iOS build-number mirror from 28 to 29.

The task is intentionally one atomic bootstrap transaction. It is not permission to broaden version logic, relax the canonical script, alter rulesets, or merge either historical PR.

## Why the former sequence is impossible

The former plan required `VERSION-GUARD-CI-001` to merge before the version repair. PR #2342 disproved that sequence on canonical `main@dbf22b...`:

- its `Canonical version contract` job `101203371687` executed the unchanged `.github/scripts/assert-native-electron-canonical.sh` and failed on `iOS build number drift: canonical=29 project=28`;
- its `CI result` job `101203476417` failed because the child result was `failure`;
- therefore the guard-only PR cannot truthfully become green while the canonical drift exists.

PR #2341 proves the other half of the cycle: its one-line `mobile/ios/project.yml` 28 -> 29 patch matches the intended product scope, but its base does not contain the required version child, so its green `CI result` cannot prove the authoritative script ran on that exact head.

A manual dispatch/rerun, skipped child, special-case, separate optional status, or historical-head run does not break this protected-main dependency. The smallest mergeable unit is therefore the two implementation files below on one exact head.

## Exact implementation allowlist

Only these implementation/config files may change:

1. `.github/workflows/ci.yml`
   - carry forward the minimal topology already proven on #2342: an automatic lightweight `Canonical version contract` child that executes the existing canonical script;
   - make required aggregate `CI result` directly depend on that child and reject every child result other than exact `success`;
   - preserve existing `pull_request`, `merge_group`, `push`, `workflow_dispatch`, existing classifier semantics, required status name `CI result`, and all other current CI domains.
2. `mobile/ios/project.yml`
   - exactly one semantic value change: `CURRENT_PROJECT_VERSION: 28` -> `29`.

Permitted additional writes in the execution PR are limited to this task's evidence/status/changelog records under `projects/telegram-fabushi-integration/**`.

Anything else is outside the allowlist.

## Explicit prohibitions

- do not edit `.github/scripts/assert-native-electron-canonical.sh`;
- do not duplicate/reimplement its version comparisons in YAML or another script;
- do not edit any ruleset, branch protection, `.github/workflows/*` other than `ci.yml`, `app-version.json`, Android version/config, desktop/mobile package versions, application source, test source, Cargo/dependencies, release workflow/tag/version logic, or project registry/root AGENTS;
- do not make the child conditional in a way that allows this bootstrap PR, future version-bearing PRs, or `merge_group` to skip it;
- do not accept `skipped`, `neutral`, manual `workflow_dispatch`, rerun-only evidence, an earlier SHA, or a non-required status as closure evidence;
- do not review, merge, rebase, retarget, force-push, or close #2341/#2342 as part of this task before a replacement bootstrap PR exists and its provenance is recorded;
- no local build/test is acceptance evidence.

## Execution preconditions

Before implementation, execution must re-read live GitHub and verify all of the following:

1. canonical main exact SHA and branch are freshly read, not assumed from this file;
2. on that main, `app-version.json.iosBuildNumber == 29` and `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 28`;
3. `.github/scripts/assert-native-electron-canonical.sh` still treats `app-version.json` as authority and requires the iOS project mirror to equal it;
4. ruleset protecting `main` still requires `CI result` and uses the merge queue;
5. #2341 and #2342 have not merged into canonical main.

If any precondition has changed, STOP as `BASELINE-MOVED / ARCHITECTURE-RETURN`; do not mechanically apply the 28 -> 29 patch or old workflow diff.

## Required implementation design

### CI topology half

Use the already-proven repository design from #2342 as evidence, not as a bypass:

- the child must run automatically and execute exactly `bash .github/scripts/assert-native-electron-canonical.sh` against a checkout containing every direct input the unchanged script requires;
- `CI result` must list the child in `needs` and, under its `always()` aggregation, explicitly fail unless `needs.<child>.result == success`;
- the workflow must continue to respond to `merge_group` so the merge queue receives the same required `CI result` topology;
- no version value or comparison is embedded in `ci.yml`.

### Version repair half

Change only the stale XcodeGen iOS mirror:

`CURRENT_PROJECT_VERSION: 28` -> `29`.

No other iOS setting changes.

## Exact-head acceptance — pull request

All of the following must be true on the **same final bootstrap PR head**:

1. changed implementation/config files are exactly `.github/workflows/ci.yml` and `mobile/ios/project.yml`; all other changed files, if any, are task-specific TFI records;
2. `mobile/ios/project.yml` semantic diff is exactly `CURRENT_PROJECT_VERSION 28 -> 29`;
3. `.github/scripts/assert-native-electron-canonical.sh` is byte-for-byte unchanged by the task and remains the single version/architecture assertion implementation;
4. automatic `pull_request` CI contains `Canonical version contract`; the job is executed, not skipped;
5. raw step/job evidence shows actual execution of `bash .github/scripts/assert-native-electron-canonical.sh` on that exact head;
6. `Canonical version contract` is `success` and same-head `CI result` is `success`;
7. automatically applicable portfolio/governance/product checks are truthful and green; no unrelated skipped heavyweight check is substituted for the canonical version child;
8. no manual-dispatch/rerun/different-SHA result is used as the required evidence;
9. independent code review approves the exact final bootstrap head. Architecture does not perform that review.

## Protected merge queue acceptance

After exact-head review acceptance:

1. use the protected merge queue only; no direct merge or bypass;
2. the `merge_group` run must report the required `CI result` for the merge-group head;
3. the same canonical version child must execute, not skip, on the merge-group run and succeed;
4. `CI result` must succeed with the child as a dependency;
5. only then may the queue merge.

The pull-request head result is necessary but is not a substitute for merge-group evidence.

## Canonical main readback

After protected merge, execution/test-release handoff must re-read canonical GitHub main and prove:

- the new exact main SHA is the accepted queue result;
- `app-version.json.iosBuildNumber == 29`;
- `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 29`;
- `ci.yml` contains the accepted canonical-version child + `CI result` dependency and still handles `merge_group`;
- the canonical script itself was not modified by this bootstrap task.

Only this readback closes `M6-PM-VB-A01` from the repository perspective.

## Historical PR disposition / provenance

- #2341 remains historical **version-only / pre-required-topology** evidence.
- #2342 remains historical **guard-only / canonical-drift-self-bootstrap failure** evidence.
- Neither old PR may be merged, rebased, retargeted, force-pushed, or used as the replacement lineage.
- Once the new bootstrap execution PR exists from freshly read canonical main and its description/records cite #2341@`2241c856...`, #2342@`570b874...`, blocker comments `5547296411` and `5547556953`, the appropriate execution/product owner may close #2341 and #2342 as superseded. Closing is not authorized before that replacement provenance exists.

## Stop conditions

STOP and return to Architecture without widening scope if any of these occurs:

- canonical baseline or 29/28 facts changed before execution;
- any implementation file outside the two-file allowlist is required;
- the canonical script would need modification;
- the version child is skipped, missing, neutral, or cannot run on pull_request/merge_group;
- same-head child or `CI result` remains failing after the two allowed implementation changes;
- failure exposes another semantic/version/architecture defect;
- ruleset/required-status topology changed;
- merge queue does not receive the required `CI result` on `merge_group`;
- review requests scope outside the allowlist.

No waiver, special-case or temporary bypass is permitted.

## Downstream order

The only allowed next execution task is this task.

`VERSION-BOOTSTRAP-001 execution -> exact-head Actions -> independent code review -> protected merge queue + merge_group Actions -> canonical main readback -> remaining post-main prerequisites -> test release`

Test release remains blocked after this bootstrap until the separately frozen/required `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001`, `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001`, and `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001` gates applicable to the broader MAINSAFE recovery are satisfied. Stable release remains a later independent gate.

## Open-source-first / official-source decision

Adopted:

- GitHub Actions official `jobs.<job_id>.needs` and `needs.<job_id>.result` model for explicit dependency/aggregation semantics: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax and https://docs.github.com/en/actions/reference/workflows-and-actions/contexts
- GitHub required-status-check semantics: required checks must pass for the relevant latest commit; https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks
- GitHub merge queue guidance: Actions required checks must listen for the separate `merge_group` event; same official troubleshooting page and merge-queue documentation.
- repository ruleset `15857448`: required status is exactly `CI result`, no bypass actors.
- repository precedent #2342: automatic canonical child + `CI result` dependency is operationally proven to propagate failure.
- `actions/checkout` (MIT) already used by repository; no new dependency.
- `actions/github-script` (MIT) remains the existing classifier mechanism; no new dependency or copied upstream implementation.
- Fabushi FCM ADR-0005: preserve cheap deterministic PR checks, aggregate `CI result`, merge queue and post-main heavy validation.

Rejected:

- a separate optional version status not required by `CI result`;
- manual dispatch/rerun as protected-main proof;
- accepting `skipped` or special-casing the bootstrap PR;
- modifying rulesets/branch protection;
- duplicating canonical version logic in workflow YAML;
- two sequential protected PRs whose first is provably unable to pass its own newly-required truth gate.

No upstream code is copied by this architecture decision.