# TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001 — event-aware exact-head checkout repair

- Project: `FAB-P0001 / TFI`
- Requirement ID: `M6-PM-VEHC-R01`
- Acceptance ID: `M6-PM-VEHC-A01`
- Status: `FROZEN / NEXT-ONLY-EXECUTABLE`
- Architecture date: 2026-09-05
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Canonical version baseline: `app-version.json.version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`; `mobile/ios/project.yml MARKETING_VERSION=1.2.22`, `CURRENT_PROJECT_VERSION=28`
- Failed predecessor candidate: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001` / PR #2343 final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`
- Independent failed review provenance: PR #2344 head `b60b8e2483333db21ca6cea068b7a1be9c0f4851`; review handoff comment `5547912758`
- Historical split provenance: #2341 `2241c856fb3da498ac99ade89007fe01dd335183`; #2342 `570b874318bfe42406c6f46f51798baed8c89e48`
- Architecture evidence: `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md`
- Decision: `projects/telegram-fabushi-integration/decisions/ADR-0014-event-aware-exact-head-checkout-gate.md`

## Goal

Repair one precisely proven CI evidence defect without changing the canonical version contract itself: the `pull_request` instance of `Canonical version contract` must execute the unchanged canonical assertion on the final product PR head itself, while the `merge_group` instance must continue to execute on the current merge-queue synthetic commit.

This is not a second VERSION-BOOTSTRAP-001. VERSION-BOOTSTRAP-001 produced a candidate whose exact-head acceptance failed independent review. This task is the successor execution contract that preserves the atomic bootstrap value/topology intent while correcting checkout identity and strengthening raw evidence.

## Decisive live evidence

Product PR #2343 is OPEN / UNMERGED with base `dbf22b467d35c8af2a074896c355a41993c8c191` and final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

Automatic `pull_request` CI run `33930830358`, canonical child job `101208897330`, and aggregate job `101209082820` all report SUCCESS. That green metadata is insufficient for the frozen exact-head acceptance.

The child raw log proves `actions/checkout@v5` fetched and checked out `refs/remotes/pull/2343/merge`; actual checkout HEAD was synthetic merge SHA `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`, with log text `HEAD is now at 265ceea Merge bf62cd9769cc24ae29fcf03c16a1f662bc7019aa into dbf22b467d35c8af2a074896c355a41993c8c191`. Only after that checkout did `bash .github/scripts/assert-native-electron-canonical.sh` run and succeed.

Therefore `REVIEW-FAIL-VERSION-BOOTSTRAP-001` is binding: the required script did not execute on the exact product head. Other green checks do not waive this mismatch. #2343 is not authorized for MERGE, test release, or stable release.

## Root cause

`actions/checkout@v5` had no explicit `ref` in the new canonical child. On a normal open `pull_request`, GitHub sets the workflow ref/SHA to the synthetic PR merge ref/merge commit, and checkout follows that event ref by default. The job metadata can still be associated with the PR head while the checked-out worktree is the merge commit. Treating metadata `head_sha` alone as proof of execution SHA is therefore invalid for this frozen acceptance.

## Required design

The implementation must make checkout identity event-aware and explicit:

- on `pull_request`, checkout must resolve to `github.event.pull_request.head.sha` or an equivalently explicit PR-head SHA exposed by the same event;
- on `merge_group`, checkout must resolve to the current merge-group commit (`github.sha` / the event's merge-group head SHA), not the historical PR head;
- on existing `push` / `workflow_dispatch` behavior, use the event's current `github.sha` unless live repository constraints prove a narrower equivalent is necessary;
- the unchanged `.github/scripts/assert-native-electron-canonical.sh` remains the single version/architecture assertion implementation;
- `CI result` remains fail-closed: it directly depends on the canonical child and fails unless the child result is exactly `success`;
- no `skipped`, `neutral`, cancellation, manual dispatch, rerun-only, historical run, different SHA, optional status, or condition relaxation may satisfy acceptance.

The smallest acceptable implementation is an event-aware `ref` on the existing `actions/checkout@v5` step. A conditional expression or mutually exclusive checkout steps are both acceptable only if they make the same identities unambiguous and preserve all existing sparse-checkout/read-only behavior. Do not add a new action/dependency merely to select a ref.

## Exact implementation/config allowlist

A NEW product PR must be created from freshly re-read canonical `main`; do not reuse, rebase, retarget, force-push, or mutate #2343.

Only these implementation/config files may change:

1. `.github/workflows/ci.yml`
   - preserve the `canonical-version-contract` child and its existing sparse input set;
   - make checkout event-aware so `pull_request` uses the exact PR head and `merge_group` uses the current merge-group SHA;
   - preserve exact command `bash .github/scripts/assert-native-electron-canonical.sh`;
   - preserve `canonical-version-contract` in `ci-result.needs` and exact child-result `success` propagation;
   - preserve existing `pull_request`, `merge_group`, `push`, `workflow_dispatch`, classifier, permissions, current CI domains and required status name.
2. `mobile/ios/project.yml`
   - because canonical main still has the pre-existing 29/28 mirror drift, preserve the atomic bootstrap repair as exactly one semantic value change: `CURRENT_PROJECT_VERSION: 28` -> `29`.
3. Task-specific evidence/status/changelog records under `projects/telegram-fabushi-integration/**`.

Anything else is outside the allowlist and requires Architecture return.

## Explicit forbidden files / operations

Forbidden files or surfaces include:

- `.github/scripts/assert-native-electron-canonical.sh`;
- every `.github/workflows/**` file other than `.github/workflows/ci.yml`;
- repository rulesets / branch protection / required-status configuration;
- `app-version.json`;
- Android version/config files;
- desktop/mobile package version sources;
- application source, test source, fixtures, generated product artifacts;
- every `Cargo.toml`, `Cargo.lock`, dependency manifest or dependency version;
- release workflows, tag logic, publishing/version logic;
- root `AGENTS.md`, `projects/PORTFOLIO.json` or unrelated project records.

Forbidden operations in this task: close, merge, rebase, retarget or force-push #2341/#2342/#2343/#2344; direct merge/bypass; execution from Architecture; reviewer-side implementation; test release; stable release.

## Execution preconditions

Execution must STOP as `BASELINE-MOVED / ARCHITECTURE-RETURN` if fresh readback no longer confirms all of:

1. canonical `main` is still the intended base and is read live immediately before branching;
2. canonical version authority is still `app-version.json` and the unchanged script still compares all required mirrors;
3. current baseline remains `version=1.2.22`, `iosBuildNumber=29`, `CURRENT_PROJECT_VERSION=28` unless Architecture explicitly replans a changed baseline;
4. required status/merge-queue control plane still expects `CI result` and `merge_group` validation;
5. #2343 remains unmerged and no equivalent exact-head checkout correction has independently landed on main.

## New product PR and final-head rule

- Create a new branch from fresh canonical main and a new product PR. The PR number is unknown until execution and must be recorded after creation.
- The final product head is the final commit after implementation and task-specific records; every acceptance item below binds to that exact SHA.
- A later record-only commit on the product PR creates a new final head and therefore invalidates earlier exact-head acceptance until automatic checks rerun on that new head.
- Historical #2343 head `bf62cd...` and synthetic merge `265ceea...` remain provenance only and cannot be reused as closure evidence.

## `M6-PM-VEHC-A01` — PR-head acceptance

All are mandatory on one final product head:

1. Diff allowlist is exactly the two implementation/config files above plus task-specific TFI records; no forbidden file is present.
2. `mobile/ios/project.yml` semantic version diff is only `CURRENT_PROJECT_VERSION 28 -> 29`.
3. Canonical script is byte-for-byte unchanged by the task and remains the single version logic.
4. Automatic `pull_request` workflow runs on the final product head; manual dispatch and rerun-only attempts are diagnostic only.
5. `Canonical version contract` executes, is not skipped/neutral/cancelled, and concludes SUCCESS.
6. Raw checkout evidence proves the checked-out worktree HEAD equals the final product head. Evidence must include the resolved checkout target and an actual HEAD readback (prefer explicit `git rev-parse HEAD`; equivalent raw checkout evidence is acceptable only when unambiguous).
7. Raw evidence proves the canonical script runs only after that exact-head checkout.
8. Same-run/final-head `CI result` concludes SUCCESS and raw aggregate evidence shows the canonical child result is exactly `success`.
9. Other required/applicable automatic checks are truthful and green; no other green check waives items 5–8.
10. Independent code review reviews this exact final product head and records PASS before any merge-queue entry.

## Independent review contract

The review group must independently inspect:

- final diff against the exact allowlist/forbidden list;
- checkout expression semantics for every triggered event;
- raw PR-head checkout HEAD identity;
- canonical script byte identity and command;
- `CI result` dependency/result propagation;
- no special-case/skipped/manual/different-SHA bypass;
- historical provenance #2341/#2342/#2343/#2344 without mutating them.

A PASS on a prior head is invalid after any product-head change.

## Protected `merge_group` acceptance

Only after the independent review PASS:

1. the appropriate downstream test-release/merge owner may place the accepted new product PR into the protected merge queue; Architecture does not do so;
2. an automatic `merge_group` workflow must run for the current merge-group SHA;
3. the canonical child must checkout the current merge-group SHA, not the PR head, and raw evidence must prove actual worktree HEAD equals that merge-group SHA;
4. the unchanged canonical script must execute after that checkout and succeed;
5. required `CI result` for the same merge-group run must succeed with the canonical child exact result `success`;
6. no direct merge/bypass is allowed.

The PR-head exact-SHA proof and merge-group synthetic-SHA proof are both required; neither substitutes for the other.

## Canonical main readback

After protected merge, the downstream owner must re-read GitHub canonical main and prove:

- canonical main equals the accepted protected-queue merge result;
- accepted event-aware checkout topology exists in `.github/workflows/ci.yml`;
- `merge_group` handling and required `CI result` dependency remain present;
- `.github/scripts/assert-native-electron-canonical.sh` remains unchanged by this task;
- `app-version.json.iosBuildNumber == 29`;
- `mobile/ios/project.yml CURRENT_PROJECT_VERSION == 29`.

Only this protected-merge + main-readback sequence can close the repository portion of `M6-PM-VEHC-A01`.

## Downstream release order

This task does not authorize test or stable release. After this task is independently reviewed, protected-merged and read back from canonical main, the broader MAINSAFE recovery must still satisfy the separately frozen applicable `IOS-FIXTURE-001`, `EVIDENCE-CONTRACT-001`, `EVIDENCE-JOURNEY-001` and other remaining prerequisites. Only then may the test-release group build packaged artifacts and run simulated-user E2E on exact canonical main. Stable release remains a later independent gate after packaged evidence review.

## Open-source-first investigation

### Adopted

- GitHub Actions official event semantics: open `pull_request` workflows use a PR merge ref/merge commit by default; the PR head SHA is exposed separately as `github.event.pull_request.head.sha`.
- Official `actions/checkout@v5` documentation provides the exact mature pattern `ref: ${{ github.event.pull_request.head.sha }}` for “Checkout pull request HEAD commit instead of merge commit”.
- GitHub merge-queue documentation: required Actions checks must listen to `merge_group`; merge-queue temporary refs contain a SHA different from the individual pull request, so merge-group acceptance must validate the current group SHA.
- Existing repository `actions/checkout@v5` dependency is retained. Its repository license is MIT. No new third-party dependency is introduced.

### Candidate evaluation

| Candidate | Decision | Reason / source impact |
|---|---|---|
| Event-aware explicit checkout: PR -> `github.event.pull_request.head.sha`; merge_group/other current event -> `github.sha` | ADOPT | Smallest repair, official GitHub semantics, no new dependency, preserves merge-queue truth |
| Keep default checkout and trust workflow `head_sha` metadata | REJECT | #2343 raw log disproves equivalence between metadata head and actual checkout HEAD |
| Treat `refs/pull/<n>/merge` as exact product head | REJECT | It is a synthetic merge commit, not the frozen product head |
| Hard-code/construct `refs/pull/<n>/head` | REJECT | More brittle than the official event head SHA and unnecessary |
| New third-party checkout/wrapper action | REJECT | Wider supply-chain/license surface with no need; existing checkout already supports exact SHA |
| Manual/rerun/optional status or accept skipped/neutral | REJECT | Bypasses protected same-head truth and fail-closed aggregation |
| Modify canonical script or duplicate comparisons in YAML | REJECT | No script defect was found; violates single-authority contract |

Official documentation is referenced/paraphrased only; no external source code is copied. The only retained external action dependency is the already-used MIT-licensed `actions/checkout@v5`.

## Stop conditions

STOP and return to Architecture if:

- fresh main/version/control-plane facts differ materially;
- any implementation/config file beyond the two-file allowlist becomes necessary;
- exact PR-head checkout cannot be proven from raw evidence;
- merge_group would no longer execute on the current merge-group SHA;
- canonical script modification appears necessary;
- canonical child is missing/skipped/neutral/cancelled or `CI result` does not fail-closed;
- another semantic/version defect appears after the allowed repair;
- review requests scope widening or any historical PR mutation.

No waiver is authorized.
