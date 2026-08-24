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
