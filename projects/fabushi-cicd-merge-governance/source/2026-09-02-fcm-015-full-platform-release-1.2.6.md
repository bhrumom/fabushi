# FCM-015 — Fabushi 1.2.6 full-platform formal release

## Requirement

Complete a fresh formal Fabushi release from canonical protected `main`: disposition all open PRs, unify a new version/changelog, run the existing CI/CD path, publish all currently supported platform/channel outputs, and verify Actions, immutable Release assets, production delivery, install/package journeys, and upgrade behavior where required by this release task.

## Live diagnosis

- Intake open PR count at task start: `0`.
- Canonical source before this repair: `main@8eeda82bfc2c94d93a55b601190dd278a530c086`, version `1.2.5`.
- Native formal release run `33613409804` built and uploaded all five platform artifacts successfully (macOS, Windows, Linux, Android, iOS), then failed only in the publisher's public-asset contract.
- The failing contract required a standalone `fabushi-*.AppImage.blockmap`; the successful Linux build and current Electron Builder AppImage contract do not produce that file.

## Open-source-first evidence

Reviewed the canonical Electron Builder documentation for AppImage/Linux auto-update behavior before changing the contract. The upstream design explicitly embeds the blockmap inside the AppImage binary; no separate AppImage blockmap needs to be published. Linux auto-update metadata remains `latest-linux.yml`, while macOS/Windows retain their own updater metadata/blockmaps. Electron Builder is already the repository's packaging/updater dependency, so this task adapts the upstream contract rather than inventing a replacement.

Decision: remove only the false standalone Linux AppImage blockmap requirement. Keep all real cross-platform release assets and exact-SHA gates mandatory.

## Release lineage

Because `1.2.5` is already frozen in existing release lineage, do not mutate or reuse it. Create `1.2.6` from a new protected-main SHA and increment native build numbers from `11` to `12`.
