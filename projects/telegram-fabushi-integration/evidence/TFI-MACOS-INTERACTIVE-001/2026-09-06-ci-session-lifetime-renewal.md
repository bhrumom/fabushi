# TFI-MACOS-INTERACTIVE-001 — App-owned CI session lifetime / truthful finish repair

- Discovery run: macOS interactive `34014501293`, attempt `1`.
- Exact tested release: `v1.2.35` -> `3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`.
- Valid App-owned device: `gha-34014501293-1-macos-app`.
- Evidence artifact: `fabushi-macos-interactive-evidence-34014501293-1`, artifact id `9983789161`, SHA-256 `d310b348e8857e9702310eb767b8ae15aeb024001d06e9843722155143c2f9b4`, about 143 MB.
- Repair base after concurrent Android release work: protected `main@8a337c3bd7395603d1161c9c348783b936ae5b2b`, canonical version `1.2.36`.

## Truthful failure

The GitHub Actions run installed the exact v1.2.35 prerelease, logged in the protected test account, let the packaged macOS App register the device itself, completed packaged App Agent Surface Playwright evidence, collected a non-empty whole-session recording and uploaded the always-on evidence artifact. The final truth gate correctly failed because the external control hold timed out after 1500 seconds.

The artifact report records `controlStatus=timeout` and `playwrightOutcome=success`. Its device-call trace contains successful `ci_session_status`, `fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, and `assert` calls, but no successful `ci_session_note`, `ci_session_finish`, or final `settings-logout`. Therefore the complete declared macOS matrix was not accepted.

The App log establishes the root cause instead of a network hypothesis. The App-owned device initially registered successfully, then the remote-device supervisor reported that the Mahayana login had expired with no refresh token available, stopped the Fabushi device agent after SIGTERM, and subsequent session synchronization failed the bounded CI session provenance/identity/lifetime contract. The live device disappeared around fourteen minutes into a twenty-five minute external-control window while the App process itself remained alive.

## Security boundary

The refresh token must remain private to the GitHub Actions runner under `RUNNER_TEMP`; it must never be copied into the packaged App, evidence artifact, device agent environment, notes, screenshots, or logs. Device gateway ownership also remains unchanged: only the installed App registers the `gha-<run>-<attempt>-macos-app` account-scoped device. No standalone Runner, KRIS, pre-existing device, or runner-owned gateway is introduced.

## Atomic repair

1. Add a CI-only renewal helper that loads the private ordinary refreshable account session, uses the existing account-session store to rotate it through `/api/auth/refresh`, then reuses the existing atomic exporter to replace the App-facing file with a fresh bounded session that still contains no refresh token.
2. During the 1500-second macOS external-control hold, renew the private session and bounded projection every 240 seconds. Renewal failure is fail-closed and recorded in `session-renewal.log`, which contains only safe timestamps/expiry observations.
3. Keep the same App-owned device identity. The Rust Host re-reads `FABUSHI_CI_ACCOUNT_SESSION_FILE`, and the packaged remote-device supervisor already restarts its own agent when the current access token changes.
4. Make the successful external lifecycle explicit: after all non-logout categories pass, the controller must write the exact READY_FOR_LOGOUT PASS note, call `ci_session_finish`, and then invoke exact production `agentId="settings-logout"` with `action="invoke"`. The hold waits for all three; premature finish or logout remains fail-closed.
5. The final evidence gate now also requires successful `ci_session_finish` and a non-empty finish-request evidence file, in addition to all six `fabushi.app.*` tools, `ci_session_status`, `ci_session_note`, the exact logout action, Playwright, video, screenshots, trace, logs and report.

## Verification contract

No local build, Electron, native, packaged, or E2E test is permitted. The helper unit test and macOS workflow contract must run through GitHub Actions. After protected merge, re-read canonical main and version because other platform release work is concurrent, publish a strictly newer macOS prerelease (at least `1.2.37` if main remains on `1.2.36`), then use only the new release's App-self-registered macOS device for the complete live matrix. The final artifact, not chat notes, is the acceptance source.