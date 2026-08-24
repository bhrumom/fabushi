# 2026-08-24 — Local-first startup performance and Release gate

## User requirement

After the Telegram local-first/settings implementation is merged, run packaged simulated-user E2E, collect the actual display/interaction time, compare it to the project performance target, and publish a new version only if the target is met. Continue until the full merge → E2E → timing → Release loop is complete.

## Existing target

`source/full-plan/part-05.txt` defines the returning-user client target as: conversation list first interactive **< 1 second** on reasonable hardware with an authenticated local cache.

## Measurement contract

- Seed a real self-hosted conversation and allow the production projection persistence path to write it.
- Fully close and relaunch Electron with the same app-data directory.
- Measure `performance.now()` from renderer navigation start until the cached conversation row is visible and clickable. This is the release-gating metric because it measures the local-first first-interaction path independently of GitHub runner process-scheduling noise.
- Also record process-launch → conversation-list-visible and renderer → composer-interactive as diagnostic metrics.
- Write JSON evidence into Playwright `test-results` and print the same evidence into the Actions log.
- Gate at `< 1000 ms`; failure blocks the Electron main quality gate and therefore blocks post-main Release publication.

## Delivery requirement

The exact accepted main SHA must pass packaged Electron E2E plus the repository-required Android/iOS simulated-user gates. Only then may the post-main delivery workflow publish the tested artifacts with a monotonic version and updater metadata.

## Canonical-main failure observed and durability repair

Canonical `main@ace59b487bb8b1838508d08acbea5f4e7e4fa775` reached the new performance E2E. The seeded conversation was present in the in-renderer projection before shutdown, but after a full Electron process close/relaunch the expected cached row was absent, so no valid `< 1000 ms` timing result could be accepted. This exposes a durability gap in relying on Chromium `localStorage` alone for the non-authoritative fast-start projection across abrupt/full process teardown.

Repair direction:

- keep Rust SQLite/Host as the only authoritative messaging state;
- keep `localStorage` as the zero-round-trip hot path when it is present;
- mirror the bounded projection through the existing Electron native `clientPersistence` store (`fabushi-native-state.json`) so full-process restart has a durable fallback;
- on startup, check local projection synchronously first, then recover the native mirror before choosing the login/HostClient path;
- mirror a recovered native projection back into `localStorage` and continue canonical Host reconciliation normally;
- require the performance E2E to prove the native mirror contains the seeded conversation before shutting down, then measure the real full relaunch.

The release gate remains `< 1000 ms` and remains blocking until the canonical-main packaged run records a passing timing artifact.

## Returning-account session persistence blocker — canonical main `197dc768`

The durable projection repair reached canonical `main@197dc768b972974aea3603eae8f80a46df4714a4`. Exact-main Electron run `32683544762` proved the native projection mirror works: after full relaunch the E2E recovered `首屏性能验收` into `localStorage`. The row still disappeared because the deterministic Rust test Feature Host reset `auth_user` on every host process start; the asynchronous `feature.auth.status` poll therefore returned signed-out and replaced Messenger with the login shell.

This is an authentication-fixture persistence defect, not a renderer projection defect. Production already restores the Rust-owned account session locally before remote validation. The deterministic test backend must model the same returning-account lifecycle so packaged E2E exercises the production contract instead of a process-local fake session.

Follow-up requirements:

- when `FeatureHostController::create_with_host_config` runs in test mode with a real runtime data directory, persist only the UI-safe deterministic test user under that data directory;
- restore that user on the next Host process so `feature.auth.status` remains logged in across a full Electron restart;
- never persist access tokens, refresh tokens, passwords, or browser polling secrets in this test session file;
- explicit `feature.auth.logout` must delete the persisted test session and a subsequent Host process must return signed-out;
- keep the existing process-local `FeatureHostController::create(..., HostMode::Test)` behavior isolated for unit tests that do not provide a durable data directory;
- the startup E2E must additionally prove the login shell does not replace Messenger after the asynchronous auth retry window;
- `< 1000 ms` remains the blocking release target and no Release may publish until exact-main packaged evidence passes.
