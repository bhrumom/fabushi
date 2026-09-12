# FCM-010.13 canonical release-chain evidence — 2026-09-12

## Scope and exact source

- Canonical source SHA for this evidence round: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- `main` was read before and during the round and remained on that exact SHA.
- This record is fail-closed: FCM-010.13 is not passed until the exact-source installed macOS App-owned full journey and final evidence gate succeed.

## FCM-010.13.8 — PR required Actions

- PR `#2530` (`[automerge-force] ci: bind macOS interactive E2E to exact release source`) merged on 2026-09-12.
- PR head: `ed0b608717ae585cf73bf6ca3b164cd018750b2f`.
- Merge commit: `f25792495c47c9a5054611bba622047e3c94517d`.
- PR-head `CI result` check `103463385262`, workflow run `34661029319`: `success`.
- Related PR-head Electron/security/Rust checks also completed successfully.
- State: **passed**.

## FCM-010.13.9 — protected merge and canonical readback

- The exact-source release bridge is present on canonical `main@7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Canonical main readback confirms `.github/workflows/macos-interactive-release-chain.yml` and `macos-interactive-app-e2e.yml` retain exact-source / immutable-release behavior.
- State: **passed**.

## Canonical same-SHA platform gates

For `main@7ee12b790e18049d2b9509b0c29128dd2ace690b`:

- `Electron macOS` check `103471995199`, run `34663960416`: `success`.
- `Electron desktop result` check `103473515478`, run `34663960416`: `success`.
- `Native Android` check `103471995025`, run `34663960421`: `success`.
- `Native iOS` check `103471994841`, run `34663960421`: `success`.
- `Require exact-main desktop and mobile E2E` check `103473542655`, post-main run `34664490101`: `success`.
- `Publish tested main artifacts to GitHub Release` check `103473560652`, post-main run `34664490101`: `success`.

## Published immutable Release

- Release ID: `387414284`.
- Tag: `desktop-1.2.56-7ee12b790e18`.
- Release is published (`draft=false`, `prerelease=false`) and immutable.
- `target_commitish`: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Git tag dereference resolves directly to commit `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- macOS asset: `fabushi-1.2.56-macos-arm64.zip`.
- Asset size: `151338366` bytes.
- Declared asset digest: `sha256:314225bc49ca203f72cf271e02c85884b6b91ef38638a91f2136f81c25f57e0c`.

## FCM-010.13.10 — automatic immutable-tag dispatch

- `macos-interactive-release-chain` run `34664577213` is a successful `workflow_run` execution on exact source `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Job/check `Dispatch exact-source App-owned macOS interactive lane` (`103473806024`) completed `success`; this is the required automatic dispatch and is not skipped.
- An earlier duplicate/precondition chain attempt was skipped; it is not used as acceptance evidence. The later Post-main-linked chain above is the accepted run.
- Downstream `macOS interactive app device E2E` run `34664585793` was created automatically with:
  - `head_branch=desktop-1.2.56-7ee12b790e18`
  - `head_sha=7ee12b790e18049d2b9509b0c29128dd2ace690b`
  - trigger actor `github-actions[bot]`
- State: **passed** for automatic exact-source dispatch.

## FCM-010.13.11 — installed App-owned packaged journey

Downstream run `34664585793`, job `103473835434`, has already completed these real installed-package steps successfully:

1. Resolve/download the exact published Release.
2. Validate the downloaded ZIP digest against Release metadata.
3. Extract and install the single top-level App to `/Applications/Fabushi.app`.
4. Verify arm64 executable, `codesign --verify --deep --strict`, Gatekeeper assessment, bundle ID and version.
5. Authenticate the protected CI test account and export only the bounded refresh-token-free App session.
6. Launch the installed Fabushi App and wait for App-owned device registration.
7. Run the Action-owned packaged App Agent semantic smoke successfully (`status`, `snapshot`, `wait`, `find`, `action`, `assert`, close/wait, final status).
8. Whole-session macOS recording began before Release resolution/install; step screenshots are collected throughout.

At the time of this evidence write, the same run is still at `Hold for @fabushi test complete macOS journey`. Its final gate requires the external controller to use that newly registered App-owned device, complete the current semantic user journey, write the required `TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=...` note, call `ci_session_finish`, then invoke exact `settings-logout`. Only after that may Playwright/log/trace/video collection and the final truthful evidence gate complete.

The currently connected device-control namespace does not expose `gha-34664585793-1-macos-app`; it exposes only the user's existing Linux/Windows/macOS devices. Replacing the CI App-owned device with a local or historical device would violate the acceptance contract, so no substitute call or fabricated trace is used.

- State: **blocked / in-progress**, not passed.
- Blocking dependency: an authenticated external controller in the protected CI test account namespace must reach the App-owned device for run `34664585793` before its interactive hold closes.

## Completion decision

- FCM-010.13.8: passed.
- FCM-010.13.9: passed.
- FCM-010.13.10: passed.
- FCM-010.13.11: blocked/in-progress.
- Overall FCM-010.13: **in-progress (fail-closed)**.
- CI latency observer compression work is not advanced in this round because the user's sequencing explicitly requires all FCM-010.13 gates to pass first.