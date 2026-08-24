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

## Canonical-main performance failure evidence

- Main SHA: `ace59b487bb8b1838508d08acbea5f4e7e4fa775`.
- Electron desktop quality gate: `32681842813` — failed only after the new full-relaunch performance case reached the expected seeded conversation assertion.
- Messenger E2E summary: 11 passed, 1 failed.
- Failure mode: the seeded `首屏性能验收` projection existed before shutdown, but `[data-testid^="peer-selfhosted:channel:"]` with that title was absent after full process relaunch.
- No timing value is accepted from this run because the release-gating row did not become interactive.
- Follow-up evidence must include durable native projection verification, `startup-performance.json`, exact-main desktop/native success, and the resulting Release tag.

## Exact-main durable-projection / auth-session evidence

- Canonical main SHA: `197dc768b972974aea3603eae8f80a46df4714a4`.
- Electron desktop quality run: `32683544762`; Host simulated user smoke job `97304464629`.
- Result: 11/12 E2E passed. The performance case recovered `首屏性能验收` into `localStorage` after full relaunch, proving the native projection mirror worked, then failed because the UI changed to the login shell before the projected peer assertion.
- Root cause: deterministic Rust test Feature Host `auth_user` was process-local; production's Rust-owned session restore path is already durable.
- Follow-up must prove persisted test account restore, logout clearing, no credential fields in persisted state, no login-shell replacement after the auth retry window, and then produce the real `< 1000 ms` timing artifact.
