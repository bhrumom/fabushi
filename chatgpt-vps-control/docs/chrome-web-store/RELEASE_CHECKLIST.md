# Chrome Web Store release checklist

## Repository/package gates

- [ ] `chrome-platform/extension/manifest.json` has a version greater than the currently published store version.
- [ ] `npm ci` completes from `chatgpt-vps-control/`.
- [ ] `npm run chrome:validate` passes.
- [ ] `node --test tests/browser-extension.test.js tests/chrome-platform.test.js` passes.
- [ ] `npm run chrome:package` produces `dist/chrome-extension/fabushi-<version>.zip`.
- [ ] ZIP contains only `manifest.json`, `app.html`, `app.css`, `app.js`, `service-worker.js`, `platform-bridge.js`, and `browser-control.js`.
- [ ] ZIP contains no legacy `popup.*`, `userscripts.js`, Marketplace `.user.js`, source credentials, native-host configuration, or remote executable code.
- [ ] Manifest has no `userScripts` permission and no legacy ChatGPT-only `host_permissions`.
- [ ] Start a signed-in Fabushi desktop build, load the staged extension, and confirm the extension shows the same desktop account without a second credential entry.
- [ ] Confirm Chats, Mini Apps, Marketplace (`platform=chrome-extension`), search, Browser and Settings surfaces work.
- [ ] Confirm **Open desktop settings** focuses/opens Fabushi Settings through Native Messaging and does not navigate Chrome to `fabushi://` or show an “Open app?” browser prompt.
- [ ] Confirm ordinary tabs from the user's current Chrome appear as Fabushi `extension` browser sessions and can be claimed/controlled without launching a second managed CDP browser.
- [ ] Perform a least-privilege permission audit and keep `PRIVACY_AND_PERMISSIONS.md` synchronized with exact production behavior.

## Publisher/account gates (manual)

- [ ] Sign in to the organization-approved Chrome Web Store developer account.
- [ ] Confirm developer registration/payment and publisher identity/verification are complete.
- [ ] Create or open the Fabushi store item and confirm ownership/authorized publishers.
- [ ] Upload the verified `fabushi-<version>.zip` artifact from the successful `Chrome Extension Web Store` workflow.
- [ ] Fill listing name, short/detailed description, category, language, homepage/support links, and support contact.
- [ ] Upload approved icon/screenshots/promotional artwork from `ASSETS.md`, showing Fabushi as a Chrome platform rather than a ChatGPT-only extension.
- [ ] Provide a public HTTPS privacy-policy URL controlled by Fabushi.
- [ ] Complete Privacy practices using verified production data flows, including native desktop-session reuse, tab metadata, permission justifications, and single-purpose description.
- [ ] Explain `debugger` and `nativeMessaging` clearly in the permission justifications: existing Chrome control and local desktop Fabushi bridge respectively.
- [ ] Resolve every dashboard warning/error and verify there is no remote-code policy violation.
- [ ] Select distribution visibility/regions and any tester groups deliberately.
- [ ] Submit for Chrome Web Store review.
- [ ] After approval, choose staged or full publication according to release policy; record store item ID/version/review outcome in release evidence.

## Post-publication smoke test

Install from the public/unlisted store URL in a clean Chrome profile, start the signed-in Fabushi desktop app, verify account reuse, Chats/Mini Apps/Marketplace, desktop Settings handoff, existing-Chrome browser control, MV3 service-worker startup, and the submitted manifest version. If a regression is found, upload a strictly higher version; Chrome Web Store versions cannot be rolled back by reusing an old version number.
