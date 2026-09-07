# Fabushi Chrome Web Store production packaging

## Release identity

- Platform: **Fabushi for Chrome** (first-class Fabushi platform, not the legacy ChatGPT/Computer Control extension UI)
- Manifest: `chrome-platform/extension/manifest.json`
- Production candidate: **0.3.0**
- Manifest format: **Manifest V3**
- Minimum Chrome version: **120**
- Toolbar action entry: **`app.html`**
- Desktop product bridge: **`com.fabushi.chrome_platform`**
- Existing-browser control bridge: **`com.fabushi.chatgpt_computer_control`**

Every Chrome Web Store update must increment `chrome-platform/extension/manifest.json` to a version greater than the version already uploaded to the store. `npm run chrome:validate` also fails if the production-candidate version in this document drifts from `manifest.json`.

## Architecture and credential boundary

Chrome is packaged from `chrome-platform/extension/`, independently from the legacy `extension/` directory. The Web Store build does not request `userScripts`, does not include `.user.js` files, and does not carry the legacy ChatGPT-only host permissions.

The extension uses two local Native Messaging channels. `com.fabushi.chrome_platform` connects the Chrome UI to the running desktop Fabushi Host for auth state, Chats, Mini Apps, Marketplace and allowed product commands. The desktop Host remains the owner of the account session: the extension never receives or persists the desktop password or refresh token. `com.fabushi.chatgpt_computer_control` exposes ordinary tabs from the user's already-running Chrome as extension browser sessions, allowing desktop computer control without launching a second CDP browser.

The extension's **Open desktop settings** action is sent through Native Messaging. The native desktop side opens `fabushi://settings/<section>` itself, so Chrome does not navigate to a custom scheme and does not show the browser's “Open app?” protocol prompt.

## Validate, test and package

From `chatgpt-vps-control/`:

```bash
npm ci
npm run chrome:release
```

`chrome:release` validates the first-class platform manifest/app/resources, credential/native-host integration markers and documented version alignment, runs the focused browser-extension/platform tests, creates the Web Store ZIP, reads the ZIP back, verifies the archived file list exactly matches the allowlisted staged tree, and writes SHA-256 evidence.

Equivalent individual commands:

```bash
npm run chrome:validate
node --test tests/browser-extension.test.js tests/chrome-platform.test.js
npm run chrome:package
```

Outputs:

- `dist/chrome-extension/fabushi-<manifest-version>.zip`
- `dist/chrome-extension/SHA256SUMS.txt`

The production ZIP puts `manifest.json` at archive root and contains only `app.html`, `app.css`, `app.js`, `service-worker.js`, `platform-bridge.js`, `browser-control.js`, and `manifest.json`. Packaging fails if legacy popup/userscript/Marketplace-user-script assets appear or if archive verification differs. Standard `zip` and `unzip` executables are required on `PATH`.

`.github/workflows/chrome-extension-web-store.yml` runs the same preflight on the Chrome platform branch and uploads the ZIP plus SHA-256 file as a GitHub Actions artifact.

## Verified branch evidence

The first-class platform release gate has passed in GitHub Actions. Run `34118863314` on `cdbfcab02419c150e9fea47d692bd5faf64eb3ac` validated Fabushi `0.3.0`, passed **10/10** focused tests, generated a **15,197 byte** `fabushi-0.3.0.zip`, verified the exact seven-file allowlist, recorded SHA-256 `2f060ff84152ff8c06c2712d26cc38d1d00a1c77836a29041039a9a77488357e`, and uploaded artifact `10017367281`. A follow-up reconnect hardening run `34119000281` on `d772c033b774eb4ccae6335d6a01c9ea8f233f9c` also passed.

## Manual unpacked smoke test

1. Run `npm run chrome:release`.
2. Start a current Fabushi desktop build signed into the test account and make sure its Chrome platform native bridge is installed.
3. Open `chrome://extensions`, enable Developer mode, then choose **Load unpacked**.
4. Select `dist/chrome-extension/fabushi-<version>/`.
5. Confirm Chrome shows no manifest or service-worker registration error.
6. Open Fabushi and confirm desktop account identity appears without a second login.
7. Verify Chats, Mini Apps, Marketplace, search and Settings surfaces.
8. Open the Browser surface and confirm ordinary tabs from the current Chrome are listed; verify desktop browser tooling reports an `extension` session rather than launching a separate managed browser.
9. Click **Open desktop settings** and confirm Fabushi desktop is focused on Settings without a Chrome custom-protocol confirmation page.
10. Inspect the MV3 service worker and confirm both native channels connect without syntax/import errors.

## Store preparation documents

- `ASSETS.md`: listing artwork and screenshot dimensions/content checklist.
- `PRIVACY_AND_PERMISSIONS.md`: permission-by-permission disclosure and privacy verification gates.
- `RELEASE_CHECKLIST.md`: upload, dashboard, review and post-publication gates.

No remote executable code is packaged. The legacy userscript implementation remains in repository history/source for other workstreams but is not loaded or shipped by this Chrome platform package.

## Publisher upload

Use the ZIP from a successful `Chrome Extension Web Store` GitHub Actions run, or a locally reproduced ZIP after all commands above pass. Complete both **Store listing** and **Privacy practices** before submission. Publisher credentials, OAuth tokens and Chrome Web Store API secrets must never be committed.

Official references:

- https://developer.chrome.com/docs/webstore/prepare
- https://developer.chrome.com/docs/webstore/cws-dashboard-listing
- https://developer.chrome.com/docs/webstore/cws-dashboard-privacy
- https://developer.chrome.com/docs/webstore/images
- https://developer.chrome.com/docs/webstore/using-api
