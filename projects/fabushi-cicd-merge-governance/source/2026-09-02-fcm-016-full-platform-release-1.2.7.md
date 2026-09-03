# FCM-016 — Fabushi 1.2.7 full-platform formal release

## Requirement
Complete a fresh formal Fabushi release from canonical protected `main`: disposition all open PRs, unify version/changelog, execute existing CI/CD, publish all supported platform/channel outputs, and verify Actions, immutable Release assets, production delivery, install/package journeys, and upgrade behavior.

## Live diagnosis
- Open PR intake before this release repair: `0`.
- `main@03341e78d2ed2c5daf1b5711429c5ed60816c0e4` published immutable desktop 1.2.6 and passed exact-main desktop/mobile/production gates.
- Exact-main 1.2.6 did not have complete Apple Store and Google Play delivery evidence, so it cannot close the requested all-channel release acceptance.
- Because 1.2.6 is immutable and already published, this closure uses a new monotonically increasing 1.2.7 release rather than mutating old lineage.

## Open-source-first evidence
GitHub Actions official documentation was reviewed before changing orchestration. `workflow_run` is retained for privileged post-gate separation, and GitHub documents `workflow_dispatch` as an allowed `GITHUB_TOKEN` workflow-trigger exception. The implementation reuses the repository's existing signed Apple Store and Google Play workflows rather than cloning upload logic or adding a long-lived PAT.

## Release identity
- Product version: `1.2.7`
- Repository Android/iOS build identity: `13`
- Formal release commit marker: `[full-platform-release]`
