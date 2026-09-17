# VERSION-EXACT-HEAD-CHECKOUT diagnosis — 2026-09-05

## Terminal architecture diagnosis

`VERSION-BOOTSTRAP-001` failed its frozen dynamic exact-head acceptance. The defect is not the canonical version script. The defect is that the `pull_request` canonical child used the event's synthetic merge ref by default, so the script ran on a different commit than the final product head.

## Canonical baseline

- repository: `bhrumom/fabushi`
- canonical `main`: `dbf22b467d35c8af2a074896c355a41993c8c191`
- `app-version.json`: `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`
- `mobile/ios/project.yml`: `MARKETING_VERSION=1.2.22`, `CURRENT_PROJECT_VERSION=28`
- project: `FAB-P0001 / TFI`

## PR topology / provenance

- #2340 — architecture records-only PR, reused by this round; no application/workflow/version implementation is authorized here.
- #2341 — historical version-only predecessor, head `2241c856fb3da498ac99ade89007fe01dd335183`; OPEN / UNMERGED provenance.
- #2342 — historical guard-only predecessor, head `570b874318bfe42406c6f46f51798baed8c89e48`; OPEN / UNMERGED provenance.
- #2343 — failed bootstrap product candidate, base `dbf22b467d35c8af2a074896c355a41993c8c191`, final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`; OPEN / UNMERGED.
- #2344 — records-only independent review, review head `b60b8e2483333db21ca6cea068b7a1be9c0f4851`; failed-review provenance.
- review handoff comment: `5547912758`; terminal review marker `REVIEW-FAIL-VERSION-BOOTSTRAP-001`.

Architecture does not close, merge, rebase, retarget or force-push any of #2341/#2342/#2343/#2344.

## Decisive Actions evidence

Product PR #2343 automatic CI run `33930830358` is SUCCESS. Relevant jobs include:

- `Canonical version contract` `101208897330` — SUCCESS;
- required aggregate `CI result` `101209082820` — SUCCESS.

The raw canonical-child log is decisive:

1. `actions/checkout@v5` fetched `+265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac:refs/remotes/pull/2343/merge`;
2. it checked out `refs/remotes/pull/2343/merge`;
3. it printed `HEAD is now at 265ceea Merge bf62cd9769cc24ae29fcf03c16a1f662bc7019aa into dbf22b467d35c8af2a074896c355a41993c8c191`;
4. HEAD readback was `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`;
5. only then did `bash .github/scripts/assert-native-electron-canonical.sh` execute and succeed.

GitHub PR metadata independently reports the same `265ceea...` as the PR's synthetic merge commit. Therefore the child succeeded on the synthetic merge, not on exact product head `bf62cd...`.

The fact that run/check metadata is associated with final product head `bf62cd...` does not cure the worktree mismatch. Other green workflows are likewise not substitutes for the frozen exact-head requirement.

## Root cause

The new canonical child in #2343 used `actions/checkout@v5` without an explicit `ref`. For an open `pull_request` event GitHub's default workflow identity is the PR merge ref/merge commit, so checkout correctly followed the event default. The architecture acceptance, however, required a different object: the final product PR head itself.

This is an event/ref identity contract defect. It is not evidence that `.github/scripts/assert-native-electron-canonical.sh` has incorrect version logic.

## Open-source-first / official investigation

### GitHub Actions official semantics

GitHub documents the `pull_request` workflow `GITHUB_SHA` / default ref as the PR merge commit on `refs/pull/<number>/merge` for an open PR. The PR head SHA is separately available through `github.event.pull_request.head.sha`.

GitHub documents `merge_group` as the separate event required for merge-queue validation. Its current temporary group commit is intentionally a different object from the individual PR head.

### actions/checkout

The official `actions/checkout@v5` README states that checkout defaults to the ref/SHA that triggered the workflow and provides a mature explicit scenario:

`Checkout pull request HEAD commit instead of merge commit` -> `ref: ${{ github.event.pull_request.head.sha }}`.

The `actions/checkout` repository license is MIT. The Fabushi repository already depends on this action. No new dependency or copied upstream implementation is necessary.

### Candidate disposition

- **ADOPT:** event-aware explicit checkout, PR -> exact event PR head, merge_group -> current event group SHA.
- **REJECT:** default PR merge checkout plus metadata-only assertion; disproven by #2343.
- **REJECT:** treat synthetic PR merge as exact product head; contradicts the frozen acceptance object.
- **REJECT:** force merge_group to use PR head; would stop validating the protected queue's combined commit.
- **REJECT:** new third-party checkout/wrapper; unnecessary supply-chain expansion.
- **REJECT:** manual/rerun/skipped/neutral/different-SHA/optional status; bypasses fail-closed truth.
- **REJECT:** modify the canonical script or duplicate comparisons; no script defect was established.

## Architecture decision

Freeze successor task `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001` with Requirement `M6-PM-VEHC-R01` and Acceptance `M6-PM-VEHC-A01`.

The new execution must create a NEW product PR from freshly read canonical main. Because canonical main still has the 29/28 mirror drift, the implementation/config allowlist remains atomic:

1. `.github/workflows/ci.yml` — only the minimal event-aware checkout correction while preserving the canonical child, unchanged script command and fail-closed required `CI result`;
2. `mobile/ios/project.yml` — only `CURRENT_PROJECT_VERSION: 28 -> 29`;
3. task-specific `projects/telegram-fabushi-integration/**` records.

PR acceptance: raw actual worktree HEAD must equal final product head before the canonical script runs. Protected merge queue acceptance: raw actual worktree HEAD must equal the current merge-group SHA before the same script runs. Both child and same-run required `CI result` must be exact SUCCESS.

## Gate disposition

- #2343: `REVIEW-FAILED / PROVENANCE-ONLY`; NOT AUTHORIZED for merge.
- test release: BLOCKED.
- stable release: BLOCKED.
- next executable task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001` only.
- execution, review, protected merge, packaged testing and release are explicitly outside this architecture round.
