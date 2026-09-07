# Privacy and permission disclosure

Fabushi for Chrome is a first-class Manifest V3 Fabushi platform. The production package contains only local HTML/CSS/JavaScript. It does not package userscripts or remote executable code.

## Credential boundary

The extension reuses the account already signed in to the Fabushi desktop application through an authenticated local Native Messaging bridge. The desktop Host remains authoritative for the account session and performs product requests. The extension must not receive, persist, export, or log the desktop password or refresh token. It receives only non-secret account status/user projection, product results, runtime events, and bridge state needed to render the Chrome Fabushi UI.

## Permission rationale

| Permission | Why it exists |
|---|---|
| `alarms` | Keeps both local native bridges alive and performs bounded reconnect/heartbeat work while the MV3 service worker sleeps. |
| `debugger` | Lets Fabushi computer control attach to a user-selected/claimed existing Chrome tab instead of launching a separate CDP browser. |
| `downloads` | Reserved for desktop-controlled browser download lifecycle operations; remove before submission if the final browser-control package no longer exercises it. |
| `nativeMessaging` | Connects to `com.fabushi.chrome_platform` for the desktop account/product Host and `com.fabushi.chatgpt_computer_control` for existing-Chrome computer control. |
| `storage` | Stores only extension-local instance/generation/claimed-tab state. Account passwords and refresh tokens are not stored here. |
| `tabGroups` | Supports lifecycle grouping for tabs created by Fabushi browser automation. |
| `tabs` | Enumerates ordinary browser tabs and tracks tabs explicitly claimed for Fabushi computer control. |
| `webNavigation` | Tracks newly created/navigated controlled tabs so browser sessions stay accurate. |

The production manifest does **not** request `userScripts` and does not declare the former ChatGPT-only host permissions. There are no explicit `host_permissions` in the first-class platform manifest.

## Data handling statements to verify before submission

The publisher must ensure the public privacy policy and Web Store Privacy practices answers match the final production path. Relevant data can include account display identity/status returned by the desktop Host, Fabushi chat/product content requested by the user, tab titles/URLs, local bridge/extension identifiers, controlled-tab state, and download metadata when download control is enabled.

Credentials, cookies, API tokens, passwords, OTPs, refresh tokens, and payment secrets must not be embedded in the extension package, listing assets, logs, or `chrome.storage`. Native bridge traffic is local to the signed-in user's machine and authenticated with a private per-user native-host secret before product commands are proxied.

## Least-privilege review gate

`debugger`, `nativeMessaging`, `tabs`, `tabGroups`, `downloads`, and `webNavigation` are review-sensitive. Before submission, verify every permission against the exact ZIP. Remove any permission not exercised by the final package and keep the Web Store justification synchronized with the code.
