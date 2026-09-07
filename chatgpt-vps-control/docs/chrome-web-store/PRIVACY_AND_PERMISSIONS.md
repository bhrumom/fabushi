# Privacy and permission disclosure

Fabushi Chrome is a Manifest V3 extension. The production app shell loads local packaged HTML/CSS/JavaScript only; it does not inject remote executable code.

## Permission rationale

| Permission | Why it exists in the current extension |
|---|---|
| `alarms` | Schedules bridge heartbeat/reconnect work in the service worker. |
| `debugger` | Enables the existing local Fabushi computer-control bridge to attach to explicitly selected browser tabs for automation/control. Chrome presents elevated-risk warnings for this permission. |
| `downloads` | Supports existing controlled browser download operations requested through the local bridge. |
| `nativeMessaging` | Connects the extension to the installed Fabushi native host (`com.fabushi.chatgpt_computer_control`). |
| `storage` | Stores extension-local bridge identity/state and userscript consent/installation state. |
| `tabGroups` | Supports grouping tabs created/managed by the existing automation bridge. |
| `tabs` | Enumerates and identifies tabs for the existing local bridge and selected-tab workflows. |
| `userScripts` | Preserves the existing user-approved Marketplace userscript runtime. This Chrome Web Store preparation task does not add userscript capabilities. |
| `webNavigation` | Tracks navigation state for controlled tabs in the existing bridge. |

## Host permissions

The manifest limits explicit host permissions to:

- `https://chatgpt.com/*`
- `https://chat.openai.com/*`

These origins support the existing ChatGPT-specific integration/userscript runtime. No additional host origin is added by the Chrome app-shell work.

## Data handling statements to verify before submission

The publisher must ensure the public privacy policy and Chrome Web Store privacy questionnaire accurately reflect the production implementation. At minimum, verify and disclose whether the extension handles tab URLs/titles, local device/bridge identifiers, user-entered content, download metadata, and userscript installation/consent state. Do not claim data is not collected, transmitted, retained, or shared unless the production native bridge/server path has been independently verified for that exact claim.

Credentials, cookies, API tokens, passwords, OTPs, and payment data must not be embedded in the extension package or store listing assets. The existing bridge documentation states that cookies are not exported; the store privacy answer must still be validated against the current packaged/native implementation before publication.

## Least-privilege review gate

`debugger`, `downloads`, `nativeMessaging`, `tabs`, `tabGroups`, `userScripts`, and `webNavigation` are review-sensitive permissions. Before Web Store submission, a maintainer must run a permission-use audit against the packaged version. Remove any permission that is no longer exercised by production code; otherwise keep the rationale above aligned with the actual feature exposed to users.
