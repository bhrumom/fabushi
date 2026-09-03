# M7-DESKTOP-005 — Left search, living avatars, updater and jellyfish icon

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-005`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IMPLEMENTING`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Branch**: `fix/tfi-m7-search-update-jellyfish`

## Objective

Apply the 2026-08-23 Telegram/Grok UI correction: keep all search activity in the left column, scope in-conversation search to the active peer, remove persistent create/story shortcuts, improve BotMark depth/organic motion, add a one-click GitHub Release desktop updater, and ship a borderless jellyfish application icon.

## Acceptance criteria

1. Global search results render inside `messenger-sidebar`; the conversation workspace does not get replaced by search.
2. Conversation header/profile search focuses the existing left search field and shows `此聊天` scope; chat/channel/application tabs disappear while scoped and message/media categories query only loaded active-conversation messages.
3. Persistent `新建群组`, `新建频道`, `我的动态` rows are absent. A single create button opens a compact menu for group/channel creation.
4. BotMark identity selection favors organic shapes and includes a jelly shape; the motion engine adds depth lighting/shadow and uses gentler default pose rotation.
5. Electron production uses `electron-updater` with GitHub provider metadata; packaged startup checks for updates and native update state is broadcast to the renderer.
6. Available/downloading/ready updates render a cloud control beside the profile footer. Clicking it downloads if necessary and then calls installer replacement/relaunch.
7. `native-electron-release.yml` refuses to publish unless DMG, macOS ZIP, `latest-mac.yml`, and ZIP blockmap are present; all remain GitHub Release assets.
8. `desktop/resources/icon.png` is 1024x1024 RGBA and uses a transparent borderless jellyfish design.
9. Relevant GitHub Actions are green before protected merge. No local application build, E2E, Cargo build or installer build is run.

## Verification

- Local lightweight checks only: `git diff --check`, BotMark static contract script, source marker checks, PNG alpha/dimension inspection.
- GitHub Actions: Electron desktop quality gate and any repository-required checks selected for the PR.
- After merge: canonical `main` readback. Release workflow validates immutable GitHub Release updater assets on the next tagged release.


## Canonical-main package repair — 2026-08-23

- PR #2073 merged through the protected merge queue as canonical main `ed1535aaeb835c2819a8cb8be77bf3519b349bd1`.
- Main Electron run `32648194025` exposed a packaging-only regression after adding the GitHub updater provider: `electron-builder` implicitly attempted to publish from ordinary CI because the package matrix did not pass `--publish never`, then failed without `GH_TOKEN`.
- Release publication remains exclusively owned by `native-electron-release.yml`; ordinary desktop quality/package CI must only build artifacts.
- Repair: canonical Electron package matrix now invokes `electron-builder --<target> --publish never`, preventing CI from mutating GitHub Releases while still generating updater metadata/assets for later release publication.
