# TFI-USERSCRIPT-RECOVERY-016 Evidence

- Project: `FAB-P0001` / `TFI`
- Task: `TFI-USERSCRIPT-RECOVERY-016`
- Status: `IN_PROGRESS / LIVE_CHROME_CONFIRMATION_PENDING`

## Verified evidence

- Source main `480ebe61ba039f15e7023bbc0253ea23c373aba0`; PRs #22/#23; Release [v2.9.30](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.30); `chatgpt-auto-confirm.user.js` is 224113 bytes with SHA-256 `d15040a5d420b0fa4cc38b195f178143a2d22a166e3357f88c7159c6b7a3b14a`.
- Parent PR #2638 merged to `main@c40442aff3d9241434c387bbf877c966aba7cdd1`; CI `34879286725` passed. Workflow repair PR #2639 merged to `main@80ef6f15f42e1399f13327889c1dde13edff8097`.
- Exact-main Electron run `34880495486` passed; Chrome package/journey run `34881462209` passed; post-main delivery run `34881675501` passed; final Release [desktop-1.2.65-80ef6f15f42e](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65-80ef6f15f42e) targets the exact main SHA.
- Chrome artifact `10362084424` is retained for 90 days and contains `fabushi-chrome-0.6.5.zip` (115937 bytes, SHA-256 `c77acc4a14742e5925b9bae91eb7f1db4eee28b64d685c74de9293cf43c709ab`), content manifest, 5 checkpoint PNGs, 2 sequential video segments, `trace.zip`, Playwright report, journey report, native journey log, and checksums. The bundled userscript in the package matches the source Release hash.
- Online standalone userscript Release is live. The current local Tampermonkey prompt recognized v2.9.30, but the replacement click remains pending explicit user confirmation; no local installation is claimed.

## Remaining evidence

- After user confirmation, update the current Chrome Tampermonkey installation and capture the live two-task rotation/session-inspection evidence. Web Store review remains separately tracked.
