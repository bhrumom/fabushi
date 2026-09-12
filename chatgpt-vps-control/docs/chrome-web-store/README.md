# Fabushi Chrome Web Store release

Production candidate: **0.6.0**

Fabushi 0.6.0 is the official Chrome extension for the Fabushi product shell,
the existing-Chrome Computer Control bridge, and the 0.4.1 userscript runner
(including the bundled ChatGPT auto-confirm workbench and Task Queue companion).
The old `ChatGPT Computer Control Bridge` extension is a migration source only
and is not part of this package.

After installation, open 设置 → Fabushi 账号 and sign in with the same Fabushi
account used by the official MCP. The extension then appears as that account's
Chrome device; no desktop app is required for browser control.

## Package contract

`npm run chrome:package` stages an explicit file allow-list and writes:

- `dist/chrome-extension/fabushi-chrome-0.6.0.zip`;
- `dist/chrome-extension/SHA256SUMS.txt`;
- `dist/chrome-extension/fabushi-chrome-0.6.0.content-manifest.json` with source
  SHA, per-file SHA-256/size, archive SHA-256, and generation timestamp.

The Web Store listing must retain one stable Fabushi extension ID. Every Chrome Web Store update must increment the version; a changed binary may never be uploaded under the same version.

Native-host installation accepts the production ID only when
`FABUSHI_CHROME_EXTENSION_ID` is configured (and, for an unpacked local copy,
the matching `FABUSHI_CHROME_EXTENSION_PUBLIC_KEY` may be supplied). Without
that setting the installer creates a clearly marked development identity and
the desktop account bridge stays fail-closed. This prevents a random unpacked
key from being mistaken for the published Web Store extension.

## Permission rationale

| Permission | Why Fabushi needs it |
| --- | --- |
| `debugger` | Attach a serialized Chrome DevTools Protocol session to a user-claimed tab, including OOPIF child sessions. |
| `nativeMessaging` | Connect the extension to the signed desktop Host and the browser-control Host. |
| `downloads` | List, wait for, and cancel downloads exposed by the Computer Control contract. |
| `tabs`, `tabGroups`, `webNavigation` | Enumerate title/URL, group automation tabs, and inherit ownership to child tabs. |
| `scripting`, `userScripts` | Preserve the 0.4.1 userscript runner, including native User Script registration and the scripting fallback. |
| `storage`, `alarms` | Persist non-secret ownership/script state and provide bounded heartbeat/reconnect. |
| `<all_urls>` | Preserve the 0.4.1 document-start page handshake used by the local script runner; executable bundled scripts still match only approved HTTPS pages. |

The extension never stores or returns passwords, cookies, refresh tokens, or
sensitive input. The browser account flow keeps only its short-lived access token
and login poll secret in trusted `storage.session`; the token is sent only to the
Fabushi account API and the account-scoped `/browser-agent` WebSocket. The desktop
Host remains an optional account and native-messaging bridge. Browser control
accepts connections only from the configured published extension ID and then
requires server-side account authentication.

## Verification and migration

The focused Chrome workflow runs the validator, contract tests, package
allow-list, packaged simulated-user journey, and uploads the ZIP/checksum/
content-manifest plus step screenshots/video/trace/report with 90-day target
retention. Desktop packaging and cross-platform simulated-user journeys remain
canonical post-main gates in the Electron workflows. After the accepted release
is installed, stop active control, detach the old Bridge, re-claim tabs with the
new generation, then remove the old Bridge and official ChatGPT extension from
each original Chrome profile through `chrome://extensions`. Only after that UI
step run `chatgpt-computer-control browser-extension cleanup-legacy` to remove
the legacy host registration and quarantine its source directory.
