# TFI-MACOS-INTERACTIVE-001 — settings-logout App-owned control repair / 1.2.34

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Protected base at version-bump start: `main@1a83e1e597010fde6252b2f8cee0d6830e018caf`
- Product repair: PR `#2390`, merged as `1a83e1e597010fde6252b2f8cee0d6830e018caf`
- Previous immutable macOS test release: `v1.2.33` -> `b736093de47034ca1ace9feefdade2abf19fe543`
- Previous interactive run: `34011598264` — external control failed while packaged Playwright and evidence upload succeeded.
- Candidate governed macOS test version: `1.2.34`; Android `androidVersionCode=29` and iOS `iosBuildNumber=29` remain unchanged.

## Failure boundary

The previous App-owned macOS journey reached installation, protected-account login, App self-registration, packaged Playwright evidence and always-upload collection. Its truthful final gate rejected the run because external semantic control could not safely complete `settings-logout` through a volatile settings navigation reference.

## Repair and release contract

PR #2390 exposes stable profile/settings navigation controls without weakening generation, route, fingerprint, remote-control opt-in, account-session, Computer Use or gateway-ownership checks. Version 1.2.34 changes only canonical version bindings required to publish a strictly newer immutable macOS test package from protected main. Cross-platform marketing-version parity is preserved; mobile build counters do not advance.

After protected merge, only `v1.2.34` built from the exact resulting canonical main SHA may be tested. Native recording must start before installation. The installed test App must authenticate the protected CI account and self-register the new account-scoped macOS device; KRIS, old devices, runner gateways and pre-existing devices remain forbidden. The complete external matrix must call `fabushi.app.status/snapshot/find/action/wait/assert` plus `ci_session_status/note/finish`, retain full video/screenshots/device trace/Playwright/log/report evidence on pass or fail, and fail closed on any missing category or evidence.
