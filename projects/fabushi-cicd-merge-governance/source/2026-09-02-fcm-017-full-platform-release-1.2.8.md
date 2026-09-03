# FCM-017 — Fabushi 1.2.8 full-platform formal release

## Requirement
Complete a brand-new formal Fabushi release from canonical protected `main`: disposition all open PRs, unify version/changelog, execute the existing GitHub Actions CI/CD, publish all currently supported platform/channel outputs, and verify Actions, immutable Release assets, production deployment, installation/package journeys, and explicit upgrade behavior.

## Live intake and baseline
- Open PR intake at task start and immediately before branch preparation: `0`.
- Canonical baseline: `main@ee70406523b983d5ff5234b2582a987fd35091f9` / Fabushi `1.2.7`.
- Baseline release health was repaired and re-verified before starting 1.2.8: exact-main desktop/mobile gates, Worker and Fabushi Pay production deployment, Google Play production delivery, iOS App Store Connect upload, macOS MAS App Store Connect upload, and immutable release evidence are green.
- Because 1.2.7 is already an immutable published identity, this task advances to a strictly newer `1.2.8` / native build `14` rather than mutating or reusing 1.2.7.

## Open-source-first evidence
This release reuses GitHub Actions' established protected-branch, merge-queue, `workflow_run`, `workflow_dispatch`, immutable GitHub Release, and repository-scoped `GITHUB_TOKEN` patterns already adopted by FCM-016 after review of GitHub's official Actions model. No new custom publisher, signing path, PAT, or duplicated store-upload implementation is introduced.

## Release identity
- Product version: `1.2.8`
- Android versionCode: `14`
- iOS build number: `14`
- Formal release commit marker: `[full-platform-release]`

## Acceptance gate
FCM-017 remains in progress until its protected PR lands on canonical `main`, exact-main required CI/package/E2E gates pass, `desktop-1.2.8` and mobile/store evidence Releases are immutable and traceable to the accepted main SHA, production deployments are green for that SHA, Apple/Google store delivery is successful, and installation plus previous-release upgrade verification completes successfully.
