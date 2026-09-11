# TFI-USERSCRIPT-RECOVERY-004 evidence index

Status: `IN_PROGRESS`

## Current evidence

- User screenshot and Computer-plugin readback, 2026-09-11 Asia/Shanghai: Work route `6aa40d6e-4c0c-83e8-b016-9df98acb467e` contains a complete final assistant reply, but multiple Fabushi launch buttons coexist; the expanded instance has no current task, is paused and reports zero scans. The preserved task is visible as a foreign recoverable workspace on the blank route.
- Root cause: synchronous old-instance shutdown did not expose/await the Web Lock request's released promise. The replacement's immediate `ifAvailable` claim could therefore fail during the specified asynchronous release step and allocate a new `tabId`.
- Source commit: `e51f9bad16190fa2c45a9b9d4b01b4412f1a5da5`.
- Source PR #4; PR CI run `34614674038`, job `103313507289`, PASS.
- Canonical source main: `448d4d8f83d5e9e558ebd17cafad2a3ea426613f`.
- Exact-main CI run `34614827011`, job `103314015767`, PASS.
- Release `v2.9.6`, ID `387136022`, exact source SHA; asset ID `557478855`, 102,370 bytes.
- Local lightweight syntax and 70/70 jsdom regressions PASS.

## Pending closure evidence

- Live installed-version readback for 2.9.6.
- Live one-root/one-launch-control proof after replacement.
- Complete Chrome video/screenshots/diagnostics for a continuous Work final → fresh validation conversation journey.
- Parent record protected merge and canonical readback.

No Fabushi application build/package/E2E is applicable.

