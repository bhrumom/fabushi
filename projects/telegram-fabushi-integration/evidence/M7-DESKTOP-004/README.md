# M7-DESKTOP-004 evidence — authenticated messaging account identity

## Production symptom

The signed/notarized canonical-main macOS artifact at `25292d1c9f4640670612a2bf794d4e7df9b32d3a` was downloaded from GitHub Actions, its artifact SHA-256 matched GitHub, its DMG and app passed codesign/stapler/Gatekeeper, and it was installed and opened on the target arm64 Mac. The running app then showed:

`bridge/invoke-failed: host operation failed: authenticated account has no stable user id`

This proved the remaining defect was above the Apple signing boundary and inside authenticated messaging access issuance.

## Root cause evidence

Production account responses serialize `user.id`, `userId`, and `userNo` as JSON numbers. `issue_messaging_access` previously selected the first present field and then called `Value::as_str()` once. A present numeric `user.id` therefore stopped resolution and produced `None` even when later compatible identity fields existed.

## Repair evidence required before TESTED

- current-head Rust/Host/CI gates green;
- protected merge to main;
- canonical-main full Electron package matrix green;
- macOS notarization final status `Accepted` and stapled;
- downloaded artifact digest equals GitHub Actions artifact digest;
- installed app, Host and ASR all validate with Developer ID Team `M4Q99K4UR4` and stable identifiers;
- app opens on the target Mac using the restored authenticated session;
- no stable-user-id banner is present and Messenger initialization succeeds without requiring a new login.

Until those facts are recorded, M7-DESKTOP-004 remains `TESTING`.
