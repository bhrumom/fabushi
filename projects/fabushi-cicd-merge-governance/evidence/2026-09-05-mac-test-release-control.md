# Mac-only test release control — 2026-09-05

Status: PREPARED

Protected `main` ruleset 15857448 requires merge queue plus `CI result`; bypass is unavailable. This release round therefore retains only the short required `CI result` control gate and one manual Mac release workflow: `.github/workflows/native-electron-release.yml`.

Long multi-platform auto workflows relevant to this integration are paused to manual-only: Electron desktop, Messaging Product Gate, Native mobile, Computer control security, Developer Fiat Commerce, Electron macOS hot package, post-main delivery, and sync-app-version-policy. Windows/Linux/Android/iOS packaging and duplicate packaged E2E are excluded.

The Mac workflow must build exact protected-main 1.2.23, Developer-ID sign, notarize/staple, create DMG + ZIP + latest-mac.yml + blockmap, write SHA256SUMS.txt, publish a GitHub prerelease, and upload a 90-day evidence artifact. Post-run run ID, head SHA, hashes, release URL and status will be appended in a follow-up records-only commit.

Rollback point: main@586a0952f17ab4b36dab9a69402b837968f5aa3f.
