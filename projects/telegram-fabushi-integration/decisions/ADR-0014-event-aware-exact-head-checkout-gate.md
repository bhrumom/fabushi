# ADR-0014 — Event-aware exact-head checkout for canonical version gate

- Status: Accepted
- Date: 2026-09-05
- Project: `FAB-P0001 / TFI`
- Decision owner: Architecture
- Related task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Evidence: `../evidence/TFI-M6-MAINSAFE-001/VERSION-EXACT-HEAD-CHECKOUT-DIAGNOSIS-2026-09-05.md`

## Context

`VERSION-BOOTSTRAP-001` correctly required the authoritative version script to execute on the exact final product PR head. Product PR #2343 has base `dbf22b467d35c8af2a074896c355a41993c8c191` and final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

Automatic CI run `33930830358` / `Canonical version contract` job `101208897330` concluded SUCCESS, but the raw job log proves `actions/checkout@v5` used `refs/remotes/pull/2343/merge` and actual worktree HEAD `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`. The log identifies that commit as `Merge bf62cd... into dbf22b...`. Only then did the unchanged canonical script run.

Independent review #2344 / handoff comment `5547912758` therefore correctly returned `REVIEW-FAIL-VERSION-BOOTSTRAP-001`: green status metadata does not prove exact product-head execution.

## Decision

Checkout identity is part of the acceptance contract and must be explicit per GitHub event:

1. `pull_request`: the canonical child checks out `github.event.pull_request.head.sha` or an equivalent explicit PR-head SHA from that event. Raw evidence must prove actual worktree HEAD equals the final product head.
2. `merge_group`: the canonical child checks out the current merge-group commit (`github.sha` / equivalent event merge-group head SHA). Raw evidence must prove actual worktree HEAD equals that current merge-group SHA.
3. existing `push` / `workflow_dispatch`: current event `github.sha` remains the default identity unless a later architecture decision narrows it.
4. the unchanged `.github/scripts/assert-native-electron-canonical.sh` remains the single version logic.
5. required `CI result` remains fail-closed and must reject every canonical child result other than exact `success`.

The successor execution remains an atomic fresh-main replacement because canonical main still has `app-version.json.iosBuildNumber=29` while `mobile/ios/project.yml CURRENT_PROJECT_VERSION=28`. Therefore the implementation/config allowlist remains `.github/workflows/ci.yml` plus the single iOS mirror change `28 -> 29`; task-specific TFI records are the only additional paths.

## Why merge-group is different from PR exact head

A pull-request head proves the candidate's own source commit. A merge-group SHA proves the candidate in the protected queue's temporary combined context. Forcing both events to use one identity would make one of those two checks dishonest. The gate therefore validates each event's intended object rather than reusing a prior green SHA.

## Invariants

- no canonical-script changes;
- no duplicated version comparison in YAML or a second script;
- no ruleset/branch-protection relaxation;
- no other workflow changes;
- no `app-version.json`, Android, package-version, application/test, Cargo/dependency or release logic changes;
- `pull_request`, `merge_group`, `push`, `workflow_dispatch` triggers and required status name `CI result` remain;
- skipped/neutral/manual/rerun-only/historical/different-SHA evidence is not closure;
- #2341/#2342/#2343/#2344 remain provenance and are not mutated by Architecture.

## Open-source-first investigation

Adopted official/mature behavior:

- GitHub Actions documents that open `pull_request` workflows use a PR merge ref/merge commit by default while the pull-request head SHA is separately available as `github.event.pull_request.head.sha`.
- `actions/checkout@v5` documents the specific scenario “Checkout pull request HEAD commit instead of merge commit” using `ref: ${{ github.event.pull_request.head.sha }}`.
- GitHub merge queue uses the separate `merge_group` event for required Actions validation; its current synthetic/group SHA is intentionally distinct from an individual PR head.
- existing `actions/checkout@v5` is retained; its repository license is MIT. No new third-party dependency or copied upstream source code is introduced.

Rejected:

- trusting workflow `head_sha` metadata without checking actual worktree HEAD;
- accepting `refs/pull/<n>/merge` as the frozen exact product head;
- hard-coding a pull ref when the official event head SHA is available;
- replacing checkout with a new third-party action;
- using manual dispatch/rerun/optional status/skipped/neutral as acceptance;
- changing canonical script or duplicating its comparisons;
- making merge-group checkout the PR head.

## Consequences

#2343 remains an unmerged, review-failed candidate and is not eligible for protected merge. A new execution PR from fresh canonical main is required. It must prove PR-head and merge-group identities separately, pass a fresh independent exact-head review, then protected merge and canonical-main readback. Test release and stable release remain blocked by this gate and the separately frozen broader MAINSAFE prerequisites.
