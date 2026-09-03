# FCM-022 — Fabushi 1.2.14 full-platform formal release

- Canonical source: protected `main` at intake SHA `cb3c5b6705e9abf8f6dea3195a87bcecff178d58`.
- Product version: `1.2.14`.
- Android versionCode: `20`.
- iOS build number: `20`.
- Formal release commit marker: `[full-platform-release]`.

## PR intake

Current open PR #2287 was reviewed for this release. It remains a Draft development line and is not eligible for the formal release because its own RustDesk fusion WBS/runtime acceptance is incomplete and its current live-official marketplace gate fails on iOS because no compatible `global-dharma` artifact is available. It must remain isolated until those gates are satisfied; it is not merged into this release.

## Acceptance gate

This release remains incomplete until the release PR lands on canonical `main`, exact-main required GitHub Actions gates succeed, the repository's existing formal store-delivery orchestration completes for supported platforms/channels, an immutable GitHub Release for `v1.2.14` is published with required assets, production deployment/version-policy synchronization succeeds, and fresh-install plus previous-formal-version upgrade validation is confirmed. Heavy builds and tests run only in GitHub Actions.
