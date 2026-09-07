# CWA-005 — First-class Chrome platform

Status: branch-verified; publisher smoke pending

## Deliverable

Build Chrome as an independent Fabushi platform rather than extending the legacy ChatGPT/Computer Control extension. The Chrome app uses the desktop account/session through an authenticated native bridge, exposes the same core product domains (Chats, Mini Apps, Marketplace, account/settings), opens desktop settings without a browser custom-protocol confirmation page, and exposes the user's existing Chrome tabs to Fabushi computer control so a separately launched CDP browser is not required.

## Acceptance result

- **Passed on branch:** new production source lives under `chatgpt-vps-control/chrome-platform/extension`, outside the legacy extension directory.
- **Passed:** new manifest has no `userScripts` permission or legacy ChatGPT-only `host_permissions`; production service worker loads only `platform-bridge.js` and `browser-control.js`.
- **Passed:** product/auth requests are proxied to the desktop Host; the extension does not persist/return password or refresh token. Desktop server reports `credentialBoundary: desktop-host`.
- **Passed:** Chrome UI queries `feature.auth.status`, calls allowed product commands, browses Marketplace with forced `platform=chrome-extension`, receives runtime events, and requests native desktop Settings handoff.
- **Passed:** browser-control bridge enumerates/claims ordinary user Chrome tabs and preserves existing CDP/OOPIF/download/tab-lifecycle functionality through extension browser sessions.
- **Passed:** production validator checks MV3 wiring, independent resources, syntax, native integrations, credential boundary, legacy-user-script exclusion and desktop Host integration.
- **Passed:** production ZIP is generated from an exact seven-file allowlist and read back for verification.
- **Pending external gate:** real packaged desktop + Chrome GUI smoke, screenshots, Chrome Web Store dashboard upload/review/publication require the publisher account/current signed desktop build.

## Open-source-first evidence

Reviewed the official `GoogleChrome/chrome-extensions-samples` Native Messaging sample (Chromium BSD-style sample) and Bitwarden `clients` browser/desktop integration (GPL-3.0; architecture reference only, no copied code). Adopted authenticated per-user native messaging, explicit allowed origins, fail-fast desktop-disconnected state, and a desktop-owned session boundary. Rejected copying Bitwarden implementation because of licensing/architecture mismatch.

## Evidence

- `Chrome Extension Web Store` run `34118863314` on commit `cdbfcab02419c150e9fea47d692bd5faf64eb3ac`: **success**.
- Validator: Fabushi `0.3.0`, version contract passed, desktop credential boundary passed, legacy userscript separation passed.
- Tests: **10/10 passed**, 0 failed.
- Package: `fabushi-0.3.0.zip`, **15,197 bytes**.
- Package SHA-256: `2f060ff84152ff8c06c2712d26cc38d1d00a1c77836a29041039a9a77488357e`.
- Verified ZIP entries: `app.css`, `app.html`, `app.js`, `browser-control.js`, `manifest.json`, `platform-bridge.js`, `service-worker.js`.
- Actions artifact: `10017367281`.
- Native-host reconnect hardening commit `d772c033b774eb4ccae6335d6a01c9ea8f233f9c`; follow-up run `34119000281`: **success**.
