# Fabushi Chrome Web Store production packaging

## Build

From `chatgpt-vps-control/`:

```bash
npm ci
npm run chrome:validate
npm run chrome:package
```

The production upload archive is written to `dist/chrome-extension/fabushi-<manifest-version>.zip`. Packaging uses an allowlist and intentionally excludes the legacy `popup.html` / `popup.js` surface because `manifest.json` opens `app.html`.

Before every upload, increment `extension/manifest.json` to a version greater than the currently published Chrome Web Store version, rerun validation/package, then inspect the ZIP contents.

## Store preparation documents

- `ASSETS.md`: required/approved listing artwork and screenshots.
- `PRIVACY_AND_PERMISSIONS.md`: permission-by-permission disclosure and privacy notes.
- `RELEASE_CHECKLIST.md`: publisher account, upload, listing, review and staged release gates.

No remote executable code is used by the extension app shell. Existing userscript runtime files are packaged only because the current service worker imports them; this workstream does not extend their behavior.
