# 2026-09-12 — FCM-010.13 canonical evidence round

## Result

FCM-010.13 remains **in-progress / fail-closed**. Canonical acceptance items FCM-010.13.8, .9 and .10 are objectively passed on exact source `main@7ee12b790e18049d2b9509b0c29128dd2ace690b`. FCM-010.13.11 is not yet passed because the required external App-owned complete user journey and final evidence gate have not completed.

## Verified canonical evidence

- PR #2530 required CI: `CI result` run `34661029319` / check `103463385262` succeeded; PR merged as `f25792495c47c9a5054611bba622047e3c94517d`.
- Exact canonical source: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Electron macOS + desktop aggregate: run `34663960416` succeeded.
- Native Android + Native iOS: run `34663960421` succeeded.
- Post-main exact-main gate + tested artifact publisher: run `34664490101` succeeded.
- Published immutable Release: `desktop-1.2.56-7ee12b790e18`, target commit `7ee12b790e18049d2b9509b0c29128dd2ace690b`, tag dereferences to the same SHA, asset `fabushi-1.2.56-macos-arm64.zip`, declared digest `sha256:314225bc49ca203f72cf271e02c85884b6b91ef38638a91f2136f81c25f57e0c`.
- Automatic release chain: run `34664577213`; exact-source dispatch job `103473806024` succeeded and was not skipped.
- Downstream immutable-tag run: `34664585793`, `head_branch=desktop-1.2.56-7ee12b790e18`, `head_sha=7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Downstream installed-package steps succeeded: Release download/digest verification, `/Applications/Fabushi.app` install, arm64/signature/Gatekeeper/bundle/version verification, protected account login, App-owned registration and Action-owned packaged semantic smoke.

## Current blocker

The downstream run is waiting at the external full-journey hold. The current execution's device-control namespace does not expose `gha-34664585793-1-macos-app`; only existing user devices are visible. The acceptance contract forbids substituting local/historical/KRIS/runner-owned devices. Therefore the required all-category semantic journey, READY note, `ci_session_finish`, exact `settings-logout`, post-journey Playwright/log/trace/video collection and final truthful evidence gate cannot yet be completed from this execution context.

## Next action

Restore/use an external controller authenticated into the protected CI test-account remote-control namespace so it can address the exact run-owned App device. If run `34664585793` expires, rerun the same immutable exact-source Release lane and complete the external journey before the hold timeout. Only then update FCM-010.13.11 and mark FCM-010.13 passed. After that, rerun the CI latency observer and compress `macos-packaged-interactive` or the next measured largest bottleneck while keeping CLI/core/contract fast feedback separate from packaged background validation.
