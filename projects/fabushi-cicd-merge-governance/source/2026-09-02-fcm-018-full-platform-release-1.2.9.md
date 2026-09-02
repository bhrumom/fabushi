# FCM-018 — Fabushi 1.2.9 full-platform formal release

## Requirement
Complete a brand-new formal Fabushi release from canonical protected `main`: disposition all open PRs, unify version/changelog, execute the existing GitHub Actions CI/CD, publish all currently supported platform/channel outputs, and verify Actions, immutable Release assets, production deployment, installation/package journeys, and explicit upgrade behavior.

## Live intake and baseline
- Open PR intake at task start: one PR, `#2287`, which is explicitly Draft/WIP and states it must remain isolated from the active formal-release lane until RDF-004/005/006 plus runtime acceptance are green. It is therefore reviewed and correctly retained unmerged rather than violating its acceptance contract.
- Canonical baseline: `main@868122cfa8ed2490053af5ed99117d93349ec022` / Fabushi `1.2.8`.
- `desktop-1.2.8` is already immutable and published from that exact main SHA; this task advances to a strictly newer release identity rather than mutating it.

## Release identity
- Product version: `1.2.9`
- Android versionCode: `15`
- iOS build number: `15`
- Formal release commit marker: `[full-platform-release]`

## Acceptance gate
FCM-018 remains in progress until its protected PR lands on canonical `main`, exact-main required CI/package/E2E gates pass, `desktop-1.2.9` and mobile/store evidence Releases are immutable and traceable to the accepted main SHA, production deployments are green for that SHA, Apple/Google store delivery is successful, and installation plus previous-release upgrade verification completes successfully.
