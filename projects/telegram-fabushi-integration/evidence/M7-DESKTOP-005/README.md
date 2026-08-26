# M7-DESKTOP-005 Evidence

## Local lightweight evidence

- Clean worktree created from canonical `origin/main` at `21aff3b187260cc845271725c9c3003e2ce5e85b`.
- `git diff --check`: pass during implementation.
- `.github/scripts/assert-bot-mark-motion.py`: pass after organic/jelly BotMark engine update.
- Desktop icon inspection: 1024x1024 RGBA with alpha (`sips` / `file`).
- No local Electron build, Playwright/E2E, Cargo build, DMG build, or native app launch was run.

## GitHub evidence

Pending PR and GitHub Actions evidence.


## Canonical-main package repair evidence

- Main Electron run `32648194025`: runtime smoke passed; Linux package failed solely because `electron-builder` auto-detected CI publishing after the GitHub updater provider was configured, with `GitHub Personal Access Token is not set`.
- The package matrix now explicitly uses `--publish never`; immutable publishing remains in the dedicated release workflow.
