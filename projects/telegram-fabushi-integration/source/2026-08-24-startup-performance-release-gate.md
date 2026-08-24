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
