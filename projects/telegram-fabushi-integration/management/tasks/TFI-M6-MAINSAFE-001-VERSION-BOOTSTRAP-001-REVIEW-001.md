# TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001-REVIEW-001

## Identity

- Project: `FAB-P0001 / TFI`
- Reviewer task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001-REVIEW-001`
- Reviewed execution task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Requirement / acceptance under review: `M6-PM-VB-R01` / `M6-PM-VB-A01`
- Product PR: `#2343`
- Review exact base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Review exact product head: `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`
- Architecture records source: `#2340@7d0325ae324f295847b1f6a6dd7bec30ae959c73`
- Architecture handoff: comment `5547662428`
- Execution handoff: comment `5547838312`
- Review date: 2026-09-05

## Reviewer scope and authority

This is an independent code-review task. It does not modify application code, tests, workflows, Cargo/dependencies, version sources, rulesets, or release controls. Reviewer writeback is restricted to `projects/telegram-fabushi-integration/**`. This review does not merge, create a test release, or publish a stable release.

## Verdict

`REVIEW-FAIL-VERSION-BOOTSTRAP-001`

The product/config diff is correctly restricted and the CI dependency/result topology is structurally sound, but the frozen exact-head acceptance contract is not satisfied by the live raw Actions evidence.

### Blocking finding `VB-RV-F01` — canonical script executed on a different checkout SHA

CI run `33930830358` and job `101208897330` are attached by GitHub metadata to product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`, are automatic `pull_request` attempt 1, and conclude `success`.

However, the job's raw log proves `actions/checkout@v5` fetched and checked out the synthetic pull-request merge ref:

- fetched ref: `refs/remotes/pull/2343/merge`
- checked-out commit: `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`
- Git log line: `HEAD is now at 265ceea Merge bf62cd9769cc24ae29fcf03c16a1f662bc7019aa into dbf22b467d35c8af2a074896c355a41993c8c191`
- only after that checkout did the step execute `bash .github/scripts/assert-native-electron-canonical.sh` and succeed.

The frozen task, ADR-0013, PR #2343 contract, architecture handoff, and this review request require the canonical script to execute on the same final product exact head and explicitly reject `different-SHA` evidence. A synthetic merge commit is not the exact product head. Therefore this is an acceptance failure even though the job status is green.

Official GitHub Actions documentation corroborates the observed behavior: for an open `pull_request`, `GITHUB_REF` is the PR merge branch and `GITHUB_SHA` is its merge commit; `actions/checkout` uses that ref by default. GitHub's documented mechanism for testing the pull-request head itself is to select `github.event.pull_request.head.sha`. This review records the semantic mismatch but does not implement a repair.

## Review matrix

| Area | Result | Reviewer finding |
|---|---|---|
| A — frozen diff / commit allowlist | PASS | 14 changed files: exactly `.github/workflows/ci.yml`, `mobile/ios/project.yml`, and task-specific TFI records. Commit chain is clean from exact base. |
| B — CI topology / propagation | STATIC PASS, DYNAMIC FAIL | Independent `Canonical version contract` child exists; `CI result.needs` includes it and requires exact child `success`; `merge_group` trigger remains. Dynamic child checkout does not target the required exact product head. |
| C — iOS version bootstrap | PASS | Only `CURRENT_PROJECT_VERSION: 28 -> 29`; canonical `app-version.json.iosBuildNumber=29` is unchanged. The combined bootstrap removes the historical 29/28 value drift without changing the canonical script or ruleset. |
| D — live PR-head Actions | FAIL | All listed workflow-run/job metadata is green and tied to `head_sha=bf62cd...`, but canonical raw log executes the authoritative script on synthetic merge SHA `265ceea...`, violating the no-different-SHA exact-head criterion. |
| E — reproducible project records | FAIL | Repository records preserve pending-at-commit truth, but execution handoff comment `5547838312` states there was no different-SHA substitution; the raw checkout log contradicts that statement. |

## Gate decision

- Protected canonical-main MERGE gate: **NOT AUTHORIZED**.
- Test release: **NOT AUTHORIZED**.
- Stable release: **NOT AUTHORIZED**.
- No reviewer-side implementation fix is performed.

## Required next action

Return the finding to the execution/architecture path so the frozen exact-head canonical-version evidence contract is made truthful without weakening the canonical assertion, required `CI result`, ruleset, or merge-queue semantics. Any repaired product head must receive new automatic Actions and then a fresh independent code review. Historical green results and the current synthetic-merge checkout result cannot be reused as exact-head closure evidence.

Only after a future independent review passes may the normal downstream order resume:

1. test-release project group advances the accepted PR through the protected canonical-main merge queue and reads back the exact canonical main;
2. test-release project group performs packaged build plus simulated-user E2E on that exact canonical main and retains full video, key screenshots, trace/report/log evidence;
3. that packaged evidence returns to the code-review project group for content review;
4. stable release is permitted only after that later evidence review passes.

## Open-source-first / provenance

No external code or dependency is introduced by this review. The review reuses and validates the repository's existing GitHub Actions model and official GitHub semantics:

- GitHub Actions event documentation: `pull_request` uses a PR merge ref/merge SHA by default and `github.event.pull_request.head.sha` identifies the PR head;
- `merge_group` remains the proper separate merge-queue event;
- existing `actions/checkout@v5` is retained as the repository action dependency; the defect is the selected ref/acceptance semantics, not a need for a new third-party action.

Rejected reviewer-side alternatives: treating metadata `head_sha` as proof of checkout SHA, accepting the synthetic merge SHA as if it were the frozen exact product head, using manual/rerun/history as closure, weakening required `CI result`, or editing product/workflow code from the review session.
