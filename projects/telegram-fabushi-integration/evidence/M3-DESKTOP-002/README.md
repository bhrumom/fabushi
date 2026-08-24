# M3-DESKTOP-002 evidence

- Project: `FAB-P0001 / TFI`
- Task: `M3-DESKTOP-002`
- Branch: `feat/telegram-local-first-settings`
- Implementation commit: `cda0bbc37c7f8b2623384fc5a9c1542aef5fcffa`
- Pull request: #2079
- Local static hygiene: `git diff --check` passed before push.
- Local build/test: not run, by repository disk-safety policy.
- GitHub Actions current-head verification: PASS.
  - CI: `32673731408`
  - Messaging Product Gate: `32673731405`
  - Fabushi self-hosted messaging: `32673731410`
  - Electron desktop quality gate: `32673731418`
- Electron Host simulated user smoke: PASS; renderer typecheck/build and Messenger E2E passed, including `Telegram-inspired settings bind supported preferences and persist fast-start projection`.
- macOS package/E2E: initial run hit an unrelated pre-existing Mini App test worker-teardown flake; rerun job `97279437431` passed. Linux and Windows package journeys also passed.
- Protected-main merge: PASS — PR #2079 merged through merge queue as `01b33d60f7d7d9add41a5fba84d21014094cb5dc`.
- Canonical-main verification: PASS — `main` points to `01b33d60f7d7d9add41a5fba84d21014094cb5dc` and contains the implementation.

## Closure

All expected CI, merge-queue, and canonical-main evidence is present. M3-DESKTOP-002 is complete.

## 2026-08-24 performance / Release continuation

The task is re-opened from administrative closure to `TESTING` under the newer repository post-main delivery rule. A packaged Playwright performance gate now records `startup-performance.json` and requires cached conversation-list first interaction in `< 1000 ms`. Final closure requires exact-main packaged E2E + mobile gates + GitHub Release/updater evidence.
