# TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001 — atomic required-gate + iOS mirror bootstrap

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VB-R01`
- Acceptance ID: `M6-PM-VB-A01`
- Status: `REVIEW-FAILED / PROVENANCE-ONLY`
- Architecture baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Historical product-only predecessor: `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` / PR #2341 @ `2241c856fb3da498ac99ade89007fe01dd335183`
- Historical guard-only predecessor: `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` / PR #2342 @ `570b874318bfe42406c6f46f51798baed8c89e48`
- Architecture evidence: `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`
- Failed product candidate: PR #2343 @ `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`
- Independent failed review: PR #2344 @ `b60b8e2483333db21ca6cea068b7a1be9c0f4851`, handoff comment `5547912758`
- Successor: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`

## Goal

Break the proven bootstrap dependency cycle in one protected, same-exact-head transaction: install the already-proven canonical version-contract child into required `CI result` **and** repair the already-proven stale iOS build-number mirror from 28 to 29.

The task is intentionally one atomic bootstrap transaction. It is not permission to broaden version logic, relax the canonical script, alter rulesets, or merge either historical PR.

## Why the former sequence is impossible

The former plan required `VERSION-GUARD-CI-001` to merge before the version repair. PR #2342 disproved that sequence on canonical `main@dbf22b...`:

- its `Canonical version contract` job `101203371687` executed the unchanged `.github/scripts/assert-native-electron-canonical.sh` and failed on `iOS build number drift: canonical=29 project=28`;
- its `CI result` job `101203476417` failed because the child result was `failure`;
- therefore the guard-only PR cannot truthfully become green while the canonical drift exists.

PR #2341 proves the other half of the cycle: its one-line `mobile/ios/project.yml` 28 -> 29 patch matches the intended product scope, but its base does not contain the required version child, so its green `CI result` cannot prove the authoritative script ran on that exact head.

A manual dispatch/rerun, skipped child, special-case, separate optional status, or historical-head run does not break this protected-main dependency. The smallest mergeable unit was therefore the two implementation files below on one exact head.

## Exact implementation allowlist

Only these implementation/config files were permitted:

1. `.github/workflows/ci.yml`
   - carry forward the minimal topology already proven on #2342: an automatic lightweight `Canonical version contract` child that executes the existing canonical script;
   - make required aggregate `CI result` directly depend on that child and reject every child result other than exact `success`;
   - preserve existing `pull_request`, `merge_group`, `push`, `workflow_dispatch`, existing classifier semantics, required status name `CI result`, and all other current CI domains.
2. `mobile/ios/project.yml`
   - exactly one semantic value change: `CURRENT_PROJECT_VERSION: 28` -> `29`.

Permitted additional writes in the execution PR were limited to this task's evidence/status/changelog records under `projects/telegram-fabushi-integration/**`.

Anything else was outside the allowlist.

## Explicit prohibitions

- do not edit `.github/scripts/assert-native-electron-canonical.sh`;
- do not duplicate/reimplement its version comparisons in YAML or another script;
- do not edit any ruleset, branch protection, `.github/workflows/*` other than `ci.yml`, `app-version.json`, Android version/config, desktop/mobile package versions, application source, test source, Cargo/dependencies, release workflow/tag/version logic, or project registry/root AGENTS;
- do not make the child conditional in a way that allows this bootstrap PR, future version-bearing PRs, or `merge_group` to skip it;
- do not accept `skipped`, `neutral`, manual `workflow_dispatch`, rerun-only evidence, an earlier SHA, or a non-required status as closure evidence;
- do not review, merge, rebase, retarget, force-push, or close #2341/#2342 as part of this task before a replacement bootstrap PR exists and its provenance is recorded;
- no local build/test is acceptance evidence.

## Execution preconditions

Before implementation, execution had to re-read live GitHub and verify all of the following:

1. canonical main exact SHA and branch were freshly read, not assumed from this file;
2. on that main, `app-version.json.iosBuildNumber == 29` and `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 28`;
3. `.github/scripts/assert-native-electron-canonical.sh` still treated `app-version.json` as authority and required the iOS project mirror to equal it;
4. ruleset protecting `main` still required `CI result` and used the merge queue;
5. #2341 and #2342 had not merged into canonical main.

## Required implementation design

### CI topology half

The intended design was:

- the child must run automatically and execute exactly `bash .github/scripts/assert-native-electron-canonical.sh` against a checkout containing every direct input the unchanged script requires;
- `CI result` must list the child in `needs` and, under its `always()` aggregation, explicitly fail unless `needs.<child>.result == success`;
- the workflow must continue to respond to `merge_group` so the merge queue receives the same required `CI result` topology;
- no version value or comparison is embedded in `ci.yml`.

### Version repair half

Change only the stale XcodeGen iOS mirror:

`CURRENT_PROJECT_VERSION: 28` -> `29`.

No other iOS setting changes.

## Exact-head acceptance — pull request

The frozen acceptance required all of the following on the **same final bootstrap PR head**:

1. changed implementation/config files exactly `.github/workflows/ci.yml` and `mobile/ios/project.yml`; all other changed files, if any, task-specific TFI records;
2. `mobile/ios/project.yml` semantic diff exactly `CURRENT_PROJECT_VERSION 28 -> 29`;
3. `.github/scripts/assert-native-electron-canonical.sh` byte-for-byte unchanged and still the single version/architecture assertion implementation;
4. automatic `pull_request` CI contains `Canonical version contract`; the job is executed, not skipped;
5. raw step/job evidence shows actual execution of `bash .github/scripts/assert-native-electron-canonical.sh` on that exact head;
6. `Canonical version contract` is `success` and same-head `CI result` is `success`;
7. automatically applicable portfolio/governance/product checks are truthful and green; no unrelated skipped heavyweight check substitutes for the canonical version child;
8. no manual-dispatch/rerun/different-SHA result is used as the required evidence;
9. independent code review approves the exact final bootstrap head. Architecture does not perform that review.

## Protected merge queue acceptance

After exact-head review acceptance the task would have required:

1. protected merge queue only; no direct merge or bypass;
2. `merge_group` required `CI result` for the merge-group head;
3. same canonical version child executes, not skips, on the merge-group run and succeeds;
4. `CI result` succeeds with the child as a dependency;
5. only then may the queue merge.

The pull-request head result was necessary but not a substitute for merge-group evidence.

## Canonical main readback

After protected merge the task would have required re-reading canonical main and proving the accepted queue result, iOS 29/29, accepted CI topology, and unchanged canonical script.

## Historical PR disposition / provenance

- #2341 remains historical **version-only / pre-required-topology** evidence.
- #2342 remains historical **guard-only / canonical-drift-self-bootstrap failure** evidence.
- Neither old PR may be merged, rebased, retargeted, force-pushed, or used as replacement lineage.

## 2026-09-05 — independent review disposition — authoritative latest

The implementation candidate created for this task is PR #2343, base `dbf22b467d35c8af2a074896c355a41993c8c191`, final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

Its static scope/topology intent does not close this task because the frozen dynamic exact-head condition failed:

- automatic CI run `33930830358` / canonical child job `101208897330` reported SUCCESS;
- raw log proves `actions/checkout@v5` checked out `refs/remotes/pull/2343/merge`, actual HEAD `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`;
- log identifies that synthetic commit as `Merge bf62cd... into dbf22b...`;
- only after that synthetic checkout did `bash .github/scripts/assert-native-electron-canonical.sh` run.

Therefore item 5 of the frozen exact-head acceptance was not met. Independent review #2344 / comment `5547912758` returned `REVIEW-FAIL-VERSION-BOOTSTRAP-001`. No sibling green check, job association metadata, manual/rerun or different-SHA evidence can waive the mismatch.

Disposition:

- this task is `REVIEW-FAILED / PROVENANCE-ONLY`;
- #2343 remains OPEN / UNMERGED and is not authorized for MERGE, test release or stable release;
- its failed candidate head and synthetic merge SHA must remain recorded as provenance;
- the unique successor is `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`, which explicitly repairs event-aware checkout identity while preserving the atomic two-file bootstrap intent;
- #2341/#2342/#2343/#2344 are not to be closed, merged, rebased, retargeted or force-pushed by Architecture.

## Open-source-first / official-source decision

The original architecture correctly retained existing GitHub Actions primitives and rejected optional/manual bypasses. The successor diagnosis adds the missing checkout-identity detail using the official `actions/checkout@v5` documented PR-head pattern and GitHub `pull_request` / `merge_group` event semantics; see ADR-0014 and `VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md`.

No upstream code is copied by this architecture decision.
