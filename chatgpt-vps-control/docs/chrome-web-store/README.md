# Fabushi Chrome Web Store production packaging

## Release identity

- Extension: **Fabushi**
- Manifest: `extension/manifest.json`
- Production candidate: **0.2.0**
- Manifest format: **Manifest V3**
- Minimum Chrome version: **120**
- Toolbar action entry: **`app.html`**

Every Chrome Web Store update must increment `extension/manifest.json` to a version greater than the version already uploaded to the store. `npm run chrome:validate` also fails if the production-candidate version in this document drifts from `manifest.json`.

## Validate, test and package

From `chatgpt-vps-control/`:

```bash
npm ci
npm run chrome:release
```

`chrome:release` is the production preflight: it validates manifest/app/resources and documented version alignment, runs the focused existing browser-extension tests, creates the Web Store ZIP, reads the ZIP back, verifies the archived file list exactly matches the allowlisted staged tree, and writes SHA-256 evidence.

Equivalent individual commands:

```bash
npm run chrome:validate
node --test tests/browser-extension.test.js
npm run chrome:package
```

Outputs:

- `dist/chrome-extension/fabushi-<manifest-version>.zip`
- `dist/chrome-extension/SHA256SUMS.txt`

The production ZIP uses an allowlist, puts `manifest.json` at archive root, intentionally excludes legacy `popup.html` / `popup.js`, then reads the completed archive back with `unzip -Z1` and requires its file list to exactly equal the staged allowlisted file list. Packaging fails closed if archive verification differs. The host running packaging therefore needs both standard `zip` and `unzip` executables on `PATH`.

`.github/workflows/chrome-extension-web-store.yml` runs the same validation, the focused existing Chrome-extension test suite and packaging on the Chrome extension branch, then uploads the ZIP plus SHA-256 file as a GitHub Actions artifact.

## Manual unpacked smoke test

1. Run `npm run chrome:release`.
2. Open `chrome://extensions`, enable Developer mode, then choose **Load unpacked**.
3. Select `dist/chrome-extension/fabushi-<version>/`.
4. Confirm Chrome shows no manifest or service-worker registration error.
5. Click the Fabushi toolbar action and confirm `app.html` opens.
6. Verify Chats, Mini Apps, Marketplace, search, loading, empty and error/retry states.
7. Verify the narrow/mobile navigation layout by reducing the extension window width.
8. Inspect the MV3 service worker and confirm its local module imports load without syntax/import errors.

## Store preparation documents

- `ASSETS.md`: listing artwork and screenshot dimensions/content checklist.
- `PRIVACY_AND_PERMISSIONS.md`: permission-by-permission disclosure and privacy verification gates.
- `RELEASE_CHECKLIST.md`: upload, dashboard, review and post-publication gates.

No remote executable code is used by the app shell. Existing userscript runtime files remain packaged because the current service worker imports them; this workstream does not extend their behavior.

## Publisher upload

Use the ZIP from a successful `Chrome Extension Web Store` GitHub Actions run, or a locally reproduced ZIP after all commands above pass. Complete both **Store listing** and **Privacy practices** before submission. Publisher credentials, OAuth tokens and Chrome Web Store API secrets must never be committed.

Official references:

- https://developer.chrome.com/docs/webstore/prepare
- https://developer.chrome.com/docs/webstore/cws-dashboard-listing
- https://developer.chrome.com/docs/webstore/cws-dashboard-privacy
- https://developer.chrome.com/docs/webstore/images
- https://developer.chrome.com/docs/webstore/using-api
