# TFI-MACOS-RELEASE-EXACT-SOURCE-001

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Trigger: queued macOS 1.2.44 release run `34023374833`
- Trigger run event SHA: `c21942daa26c0a5dd143f9f24bf180f506895cc5`
- Live canonical main when defect was observed: `43d8a1530868c2a8958778ae10e4ac9e8314aba8`
- Version: `1.2.44` (not published when this task was opened)

## Problem

The workflow is named and documented as an exact protected-main release, but `actions/checkout` used `ref: main`. A run queued at source SHA `c21942...` remained pending while protected main advanced to `43d8a153...`. If a runner were later allocated, checkout would resolve the then-current mutable main instead of the run's immutable GitHub event SHA. That makes the release artifact/tag source different from the run identity and from the recorded release evidence contract.

Run `34023374833` was therefore cancelled before package/sign/notarize/publish work. This is a release-source binding defect, not a product runtime failure.

## Single-issue fix

1. Checkout `${{ github.sha }}` rather than mutable `main`.
2. Bind step must assert `git rev-parse HEAD == $GITHUB_SHA`.
3. Keep the existing `require-release-source-gates.sh` ancestry/required-check gate; it verifies the immutable source is still in protected main history and has the required test-tier CI result.
4. Add a dependency-free publishing guardrail that rejects reintroduction of `ref: main` and requires both exact-source strings.

## Acceptance

- PR-head CI/governance gates pass in GitHub Actions.
- Protected merge completes from latest canonical main.
- Because `1.2.44` has never been published, the merge may keep the same strictly-newer candidate version `1.2.44` relative to the last published macOS `v1.2.40`.
- The workflow change itself triggers a new macOS test-release run whose `head_sha` equals its checkout/build `HEAD_SHA`; release `v1.2.44` must target that exact SHA.
- Full latest-release App-owned macOS interactive retest remains mandatory afterward.

## 2026-09-06 contract follow-up

Windows governed version PR #2426 exposed one stale dependency-free contract in `fabushi-embedded-runtime-source.test.js`: the product workflow correctly moved to exact run source (`ref: ${{ github.sha }}` and `HEAD == $GITHUB_SHA`) in #2424, but the embedded-runtime test still asserted the retired mutable-main equality. The follow-up changes only that test expectation to the new exact-source invariant and explicitly rejects `ref: main`; release behavior is unchanged.
