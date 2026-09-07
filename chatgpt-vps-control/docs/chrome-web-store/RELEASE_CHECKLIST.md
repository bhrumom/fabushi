# Chrome Web Store release checklist

## Repository/package gates

- [ ] `extension/manifest.json` has a version greater than the currently published store version.
- [ ] `npm ci` completes from `chatgpt-vps-control/`.
- [ ] `npm run chrome:validate` passes.
- [ ] `npm test` passes for the repository's existing control/extension tests.
- [ ] `npm run chrome:package` produces `dist/chrome-extension/fabushi-<version>.zip`.
- [ ] ZIP contains `manifest.json`, `app.html`, `app.css`, `app.js`, `service-worker.js`, `background.js`, `userscripts.js`, and approved Marketplace runtime assets only.
- [ ] No secrets, local native-host configuration, test fixtures, source maps with secrets, or legacy popup files are included.
- [ ] Load the staged directory with Chrome `chrome://extensions` developer mode and verify action opens Fabushi, navigation/search work, loading/empty/status states render, and service worker registers without errors.
- [ ] Perform a least-privilege permission audit and keep `PRIVACY_AND_PERMISSIONS.md` synchronized with production behavior.

## Publisher/account gates (manual)

- [ ] Sign in to the organization-approved Chrome Web Store developer account.
- [ ] Confirm developer registration/payment and publisher identity/verification are complete.
- [ ] Create or open the Fabushi store item and confirm ownership/authorized publishers.
- [ ] Upload the production ZIP.
- [ ] Fill listing name, short/detailed description, category, language, homepage/support links, and support contact.
- [ ] Upload approved icon/screenshots/promotional artwork from `ASSETS.md`.
- [ ] Provide a public HTTPS privacy-policy URL controlled by Fabushi.
- [ ] Complete the Privacy practices questionnaire using verified production data flows, including permission justifications and single-purpose description.
- [ ] Resolve every dashboard warning/error and verify there is no remote-code policy violation.
- [ ] Select distribution visibility/regions and any tester groups deliberately.
- [ ] Submit for Chrome Web Store review.
- [ ] After approval, choose staged or full publication according to release policy; record store item ID/version/review outcome in release evidence.

## Post-publication smoke test

Install from the public/unlisted store URL in a clean Chrome profile, confirm the installed version matches the submitted manifest version, open the Fabushi action, verify Chats/Mini Apps/Marketplace/search and basic states, and check the MV3 service worker console for startup errors. If a regression is found, upload a strictly higher version; Chrome Web Store versions cannot be rolled back by reusing an old version number.
