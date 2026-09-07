# CWA-005 — First-class Chrome platform

Status: in-progress

## Deliverable

Build Chrome as an independent Fabushi platform rather than extending the legacy ChatGPT/Computer Control extension. The Chrome app must use the desktop account/session through an authenticated native bridge, expose the same product domains (Chats, Mini Apps, Marketplace, account/settings), open desktop settings without a browser custom-protocol confirmation page, and expose the user's existing Chrome tabs to Fabushi computer control so a separately launched CDP browser is not required.

## Acceptance

- New platform source is outside `chatgpt-vps-control/extension` and the production Web Store package is built from the new platform source.
- New manifest has no `userScripts` permission and the new service worker does not load legacy userscript runtime code.
- Extension native bridge never persists or returns the desktop refresh token/password; product calls are proxied through the desktop Host session.
- Extension can query `feature.auth.status`, browse Marketplace with `platform=chrome-extension`, issue allowed product commands, receive runtime events, and request desktop Settings focus.
- Browser control can enumerate/claim/control ordinary user Chrome tabs through the extension/native bridge path.
- Production validation checks MV3 resources, JS syntax, native protocol, no remote executable code, no legacy userscript files in ZIP, and desktop bridge integration markers.
- GitHub Actions produces and verifies the Web Store ZIP.

## Open-source-first evidence

Reviewed the official `GoogleChrome/chrome-extensions-samples` Native Messaging sample (Chromium BSD-style sample) and Bitwarden `clients` browser/desktop integration (GPL-3.0; architecture reference only, no copied code). Adopt: authenticated per-user native messaging, explicit allowed origins, fail-fast desktop-disconnected state, and a desktop-owned session boundary. Reject copying Bitwarden implementation because of licensing/architecture mismatch.

## Evidence

Pending implementation commits and GitHub Actions run.
