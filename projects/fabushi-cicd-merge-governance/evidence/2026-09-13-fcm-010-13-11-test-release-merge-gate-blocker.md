# FCM-010.13.11 test-release merge-gate blocker — 2026-09-13

Status: **BLOCKED / fail-closed**

This record is test-release/governance evidence only. It does not modify product code, tests, workflows, dependencies, versions, or the reviewed product head.

## Reviewed binding revalidated

- Repository: `bhrumom/fabushi`
- Product PR: `#2561` — `fix(fcm): restore production assistant unread transition`
- Reviewed exact head: `3565c9d483cb29e7729e3003e2b844b46124e18f`
- Reviewed exact PR base: `9785d8e1b71e0d61cf31541af28b910d5be58bd9`
- `spec_digest`: `391e7a3ee4bda068398ff166f45371391a877d728ebc16e4fe96802a4a310307`
- `review_key`: `037fe69d1c84279ffc971208c3454ba7bb5bf9c68a3bc63d9093a3ba0b5d8918`
- Review handoff comment: `5647344132`
- Independent review records: PR `#2567`, head `0f5b6d869c41da338f473dada5e162dff31bee0c`
- Review evidence: `projects/fabushi-cicd-merge-governance/evidence/2026-09-13-fcm-010-13-11-pr2561-exact-head-review-3565c9d4.md`
- Review verdict: `REVIEW-PASS`; P0=0, P1=0, P2=0, other-blocking=0.
- Exact-head `CI result`: success.

## Protected-main facts

Live read before the attempted queue transition:

- Active ruleset: `15857448` / `main-merge-queue`
- Target: `main`
- Queue merge method: `SQUASH`
- Required ruleset check: `CI result`
- Bypass actors: none
- Pre-merge canonical `main`: `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`

The repository's canonical `.github/workflows/automerge.yml` requires successful workflow-level product gates before calling GitHub's native `enqueuePullRequest`. For this PR's changed paths it required `CI`, `Messaging Product Gate`, and `Electron desktop quality gate`.

## Queue attempt and exact blocker

To use the existing protected path, test-release temporarily added the `automerge` label and marked PR `#2561` ready for review. `Explicit automerge` run `34707144571`, job `103589139385`, evaluated the unchanged reviewed head and exited successfully **without enqueueing**.

The job log states exactly:

`PR #2561 head 3565c9d483cb29e7729e3003e2b844b46124e18f is still waiting for: Messaging Product Gate`

There was no `pr-2561` merge-group run, PR `#2561` remained unmerged, and canonical `main` remained `6b77ac34060e1733dd8d0a900987a5dd2471a0bb`.

The reviewed exact head's `.github/workflows/messaging-product-gate.yml` is currently:

```yaml
name: Messaging Product Gate
on:
  workflow_dispatch:
jobs:
  paused:
    runs-on: ubuntu-latest
    steps:
      - run: echo 'Automatic messaging gate paused for 2026-09-05 Mac test release.'
```

Therefore the required `Messaging Product Gate` cannot naturally arise from the PR/ready/workflow-run path for this exact head. Manually dispatching this paused/no-op workflow merely to manufacture a successful run would weaken the merge authorization contract and was not used.

## Fail-closed action

Because the product PR was not actually queued, test-release stopped before merge, Release creation, packaged exact-main acceptance, production controller dispatch, or downstream video review.

To prevent a later manual/no-op gate run from causing unintended automatic enqueue while the blocker is unresolved:

- removed `automerge` from PR `#2561`;
- converted PR `#2561` back to draft;
- preserved the reviewed exact product head unchanged at `3565c9d483cb29e7729e3003e2b844b46124e18f`.

No direct merge, admin bypass, force push, ordinary main push, Release creation, production target reuse, or downstream VIDEO_REVIEW was performed.

## Required next gate

The sole next gate is architecture/execution remediation of the repository's contradictory merge authorization contract so that the PR-required `Messaging Product Gate` can produce truthful, non-no-op evidence through the intended protected flow. Any remediation that changes product/workflow semantics must go through its own normal review and protected merge process. After that, #2561 must be revalidated against the then-current exact binding before test-release retries the protected queue; no old queue attempt, Release, target, or artifact may be reused.
