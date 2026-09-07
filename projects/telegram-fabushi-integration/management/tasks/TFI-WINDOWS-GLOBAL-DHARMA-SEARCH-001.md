# TFI-WINDOWS-GLOBAL-DHARMA-SEARCH-001 — Windows `小程序` 搜索安装全球法布施

- Project: `FAB-P0001 / TFI`
- Platform: Windows / Electron Desktop
- Status: `TESTING`
- Canonical baseline: `main@9f8ab6fd960c8563d2ee8c1c58b1d421f734c1b4`
- Branch: `fix/tfi-windows-miniapp-search-entry-20260907`
- PR: `#2476`
- Heavy build/test policy: GitHub Actions only; no local build/test

## User acceptance target

1. Global/ChatGPT-style search enters the Apps surface and exact query `小程序` discovers the official `全球法布施` Mini App.
2. The user can install it from that result and the same filtered result remains visible as installed with `打开` available.
3. Existing full Global Dharma desktop journey remains green: Bot projection, natural-language WebMCP execution, `打开应用` Telegram-like Web UI, Bot/UI shared revision, controlled Fabushi account session, exact CNY 1080 lifetime purchase, restore, canonical/server-authoritative entitlement, local prayer-wheel gate/start, restart recovery, and logout cleanup.
4. Required evidence includes step screenshots, WebM session video, Playwright trace/report/logs. Production payment-provider secrets and real-money charging are out of scope; deterministic CI validates the canonical commerce/entitlement contract without a real charge.
5. `@fabushi test` / device plugin is optional evidence for this acceptance. If unavailable, deterministic GitHub-hosted simulated-user E2E must continue and must not be replaced by an unverified PASS claim.

## Root cause and repair history

### Attempt 1 — test login race

- Head: `6f65231c74484996d070e3175251e1fdffac6fe6`
- Electron run: `34068202125`
- Result: `27/28`; the new entry test failed before search because the browser-login button was still disabled during DOM/session hydration.
- Failure artifact: `9999659978`, SHA256 `8f0fa533cc2f07a5a92294c98418a3059a4d69ebe85ab2f709145bf14da4112b`.
- Repair: wait for the real login control to become enabled and for the login gate to disappear.

### Attempt 2 — exact `小程序` did not discover Global Dharma

- Head: `a3fc566f5840f77c695cc9b04ee85852f20b6a8c`
- Electron run: `34068384791`
- Result: `27/28`; the test reached global Apps search but `global-dharma` was absent for exact query `小程序`.
- Failure artifact: `9999709842`, SHA256 `999b47f75a604d4285400834329dd256f5fd40fed1853e54f2437e71d1bc8f37`.
- Repair direction: generic `小程序` / `Mini App` queries are Apps-category discovery, not only title/description content search.

### Attempt 3 — second client-side filter still removed the app

- Exact-base head: `71a2ac51dd8d879b73a712e119f47e9c33946c9c` on then-canonical `main@694218dc9a427670fec610e458223646d2d4c461`.
- Electron run: `34068896531`
- Result: `27/28`; Host-side query normalization alone was insufficient because `GlobalSearchWorkspace` re-filtered summaries by the literal user query.
- Failure artifact: `9999860729`, SHA256 `839325b9f33c5bf9f0bd749444a389c0822c38948c3aeacb75d209a8713eac77`.
- Repair: preserve the true `小程序 · Mini App` category in Marketplace result metadata consumed by the second client filter.

### Attempt 4 — discovery passed, post-install refresh hid the installed app

- Head: `ee45af57045bad81e855ef4876051c269cc2d70a` (PR merge ref `3e03d023f07872ea0d6e156c91de589469376d65`).
- Electron run: `34069263472`
- Result: `27/28`; `01-search-miniapp-finds-global-dharma.png` proved discovery was fixed, but after installation `installMiniApp()` refreshed Marketplace data with `miniAppQuery` while the global search box still contained `小程序`, so the category metadata disappeared and `打开` could not remain visible.
- Failure artifact: `9999986933`, SHA256 `8c8668ebf4615f33c631b64d528f535f7f210f43ad06970099474620dc90c920`.
- Repair: project the Mini App category on every Marketplace summary, including unfiltered install/uninstall refreshes; production summaries already carrying the category are preserved.

## Latest verified pre-merge evidence

- Exact-base head: `8701a3ed2b8dbbc4bee36590708e22e0bae9c9e0`, merged with `main@9f8ab6fd960c8563d2ee8c1c58b1d421f734c1b4` before validation.
- Electron run: `34069692447`.
- Real Linux Rust Host simulated-user step: `success`.
- Evidence artifact: `10000096527`, `electron-prepackage-e2e-34069692447-1`, SHA256 `4e19cb1c38806bc61ee1bb117df86675d5ca30de77f1930b096a35adbbe12781`.
- Focused entry evidence present:
  - `01-search-miniapp-finds-global-dharma.png`
  - `02-global-dharma-installed-from-miniapp-search.png`
  - `miniapp-search-entry-user-journey.webm`
  - focused Playwright `trace.zip`
- Full Global Dharma parity evidence present in the same artifact:
  - screenshots `01-authenticated-messenger.png` through `12-logout-clears-miniapp-session-and-execution.png`
  - `global-dharma-user-journey.webm`
  - `global-dharma-user-journey-restart-logout.webm`
  - full parity Playwright `trace.zip`

## Remaining gates

1. Re-run required PR gates on the final docs+code head and fail closed on any new semantic regression or canonical-main drift.
2. Protected merge #2476 only after required gates are green.
3. On exact merged canonical main, require the Windows matrix/package gate and post-main exact-SHA Release delivery.
4. Because existing `windows-interactive-app-e2e.yml` hard-waits for live `@fabushi test`, close the separate plugin-independent packaged Windows Global Dharma acceptance gap as a new atomic task/PR, reusing the already-merged macOS exact-Release simulated-user pattern rather than blocking on the device plugin.
5. Final release acceptance stays `PENDING` until the latest Windows Release asset is installed/tested from its exact source SHA and video/screenshots/trace/report/log links are read back from GitHub.
