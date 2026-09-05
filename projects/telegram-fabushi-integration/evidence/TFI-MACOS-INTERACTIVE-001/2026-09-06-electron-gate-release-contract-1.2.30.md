# TFI-MACOS-INTERACTIVE-001 — restored Electron gate release-contract drift / 1.2.30

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Protected main after version-parity repair: `8cf204380559d4a997c96ddf6b44ae876dd3eb0d`
- Version-parity PR: `#2383`
- Protected merge-group CI: `33999592781` (`success`)
- Real restored Electron PR run: `33999527798`
- Failing Electron Linux job: `101395785389`

## Failure boundary

PR #2383 repaired the first restored-gate defect: the canonical architecture/version assertion now succeeds for the PR merge ref. The same real Electron run then reaches the dependency-free runtime/source contracts and fails on a separate release-contract drift:

1. the packaged-runtime source contract requires every full Electron packager to expose an explicit `working-directory: chatgpt-vps-control` Computer Use dependency-install step before bundle staging, while the current macOS test release workflow performs the same install inside one combined shell step; and
2. a later source contract still asserts obsolete unified-release strings and asset layout instead of the canonical tiered `require-release-source-gates.sh` + immutable GitHub prerelease policy already enforced by the repository's rollback drill.

This is not the version-parity defect and is therefore isolated to a new PR and a strictly newer comparable macOS test version.

## Atomic repair

Version `1.2.30` keeps Android version code and iOS build number at `29`, and changes only:

- canonical semantic-version metadata/guards from `1.2.29` to `1.2.30`;
- the macOS test release dependency install into two semantically equivalent explicit steps, including `working-directory: chatgpt-vps-control`, before Computer Use bundle staging;
- the stale unified-release source assertions so they now verify the live canonical protected-main ancestry/source-gate policy, immutable-release refusal, exact target SHA, checksums, and GitHub release creation.

The existing Computer-control security workflow assertions and platform-control-plane fail-closed assertions remain intact. No product behavior, protected-branch rule, release-source gate, account/session handling, App-owned gateway ownership, Computer Use safety policy, or functional coverage is weakened.

A published `v1.2.29`, if produced while its exact-main Electron gate remains red on this independent contract defect, is intermediate evidence only and must not enter interactive acceptance. The next interactive candidate must be the newest immutable release whose exact protected-main source has the restored real Electron quality gate green.
