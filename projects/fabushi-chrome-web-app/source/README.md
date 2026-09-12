# Source intake

`2026-09-12-official-account-browser-direct.md` records CWA-007: independent
Chrome login and official same-account MCP direct browser control.

The dated requirement is source/2026-09-12-user-requirement.md. It records the request for
FAB-P0011/CWA, CWA-006, version 0.5.0, complete Bridge command/event parity, retention of
Fabushi 0.4.1 product and automation surfaces, and removal of old extensions only after
verified migration.

Open-source-first survey:
- Chrome Native Messaging: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging
- Chrome Debugger API: https://developer.chrome.com/docs/extensions/reference/api/debugger
- GoogleChrome nativeMessaging sample: https://github.com/GoogleChrome/chrome-extensions-samples/tree/main/api-samples/nativeMessaging
- GoogleChrome Debugger sample: https://github.com/GoogleChrome/chrome-extensions-samples/tree/main/api-samples/debugger
- Chrome Web Store API v2 guide: https://developer.chrome.com/docs/webstore/using-api
- Chrome Web Store API v2 upload/publish reference: https://developer.chrome.com/docs/webstore/api/reference/rest/v2

Decision: adapt only the official public framing, lifecycle and API model. No third-party
implementation is copied; no incompatible or unmaintained dependency is introduced.
The Web Store workflow follows the official v2 upload, fetchStatus and publish model, keeps
review enabled, and is manual/exact-SHA bound because listing creation and developer
credentials are external account operations.

0.4.1 compatibility source audit (2026-09-12): the installed unpacked Fabushi package at
`/Users/gloriachan/Downloads/fabushi-0.3.0` was inspected read-only. Its service worker
imports `platform-bridge.js`, `browser-control.js`, and `userscript-runner.js`; the runner
depends on `userscript-core.js`, `userscript-content.js`, `userscript.css`, and
`userscript/chatgpt-auto-confirm.user.js`. Those resources are now staged under the
first-class package with the same public message/storage/lifecycle contract and with a
small reject-list for remote/dynamic script code. The local path is provenance evidence,
not a source-of-truth dependency for future builds.

CWA-007 extends the current candidate to 0.6.0 with independent account login and
official same-account browser-agent registration; see the dated intake and ADR-0002.
