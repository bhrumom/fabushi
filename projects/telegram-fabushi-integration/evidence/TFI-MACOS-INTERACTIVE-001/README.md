# TFI-MACOS-INTERACTIVE-001 evidence ledger

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Status: `TESTING`
- Canonical baseline at enablement start: `143c5cf10aed9e6d60810ec6c886acd2c20fa609`
- Latest published macOS test package at enablement start: `v1.2.23`, target `16b56277e2116b73f98f0406a323919de6d7728a`

## Attempt ledger

No macOS App-owned `@fabushi test` attempt has completed yet. The first workflow run created by the platform-enablement PR must append exact source SHA, release tag/version/target, workflow run and job IDs, timestamps, artifact names/links, device id, PASS/FAIL, failed assertion(s), and any defect record opened from the result.

## Evidence rules

A GitHub release upload is not proof of interaction. An online GitHub runner is not a Fabushi device. Evidence is valid only when the installed macOS Fabushi App has logged into the protected test account, registered itself through the account-scoped device gateway, been discovered by `@fabushi test`, and preserved the required video/screenshots/trace/reports/logs on both PASS and FAIL.
