# FCM-010.13 canonical release-chain evidence — 2026-09-12

## Scope and exact source

- Canonical product source SHA for this evidence round: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- This record is fail-closed: FCM-010.13 is not passed until the exact-source installed macOS App-owned full journey and final evidence gate succeed.

## FCM-010.13.8 — PR required Actions

- PR `#2530` (`[automerge-force] ci: bind macOS interactive E2E to exact release source`) merged on 2026-09-12.
- PR head: `ed0b608717ae585cf73bf6ca3b164cd018750b2f`.
- Merge commit: `f25792495c47c9a5054611bba622047e3c94517d`.
- PR-head `CI result` check `103463385262`, workflow run `34661029319`: `success`.
- State: **passed**.

## FCM-010.13.9 — canonical same-SHA gates and Release

For `main@7ee12b790e18049d2b9509b0c29128dd2ace690b`:

- `Electron macOS` check `103471995199`, run `34663960416`: `success`.
- `Electron desktop result` check `103473515478`, run `34663960416`: `success`.
- `Native Android` check `103471995025`, run `34663960421`: `success`.
- `Native iOS` check `103471994841`, run `34663960421`: `success`.
- `Require exact-main desktop and mobile E2E` check `103473542655`, post-main run `34664490101`: `success`.
- `Publish tested main artifacts to GitHub Release` check `103473560652`, post-main run `34664490101`: `success`.

Published Release:

- Release ID: `387414284`.
- Tag: `desktop-1.2.56-7ee12b790e18`.
- Published (`draft=false`, `prerelease=false`) and immutable.
- `target_commitish`: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Git tag dereference resolves directly to `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- macOS asset: `fabushi-1.2.56-macos-arm64.zip`, asset ID `558368830`, size `151338366` bytes.
- Declared asset digest: `sha256:314225bc49ca203f72cf271e02c85884b6b91ef38638a91f2136f81c25f57e0c`.
- State: **passed**.

## FCM-010.13.10 — automatic immutable-tag dispatch

- `macos-interactive-release-chain` run `34664577213` is the accepted successful `workflow_run` on exact source `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- `Dispatch exact-source App-owned macOS interactive lane` check/job `103473806024` completed `success`; it was not skipped.
- An earlier duplicate/precondition attempt was skipped and is not acceptance evidence.
- The chain automatically created downstream `macOS interactive app device E2E` run `34664585793` with `head_branch=desktop-1.2.56-7ee12b790e18`, `head_sha=7ee12b790e18049d2b9509b0c29128dd2ace690b`, actor `github-actions[bot]`.
- State: **passed**.

## FCM-010.13.11 — installed App-owned packaged journey

Downstream run `34664585793`, job `103473835434`, proved the installed-package portion is real:

1. Exact Release resolution/download and ZIP digest verification: success.
2. Install the single top-level App to `/Applications/Fabushi.app`: success.
3. arm64 executable, `codesign --verify --deep --strict`, Gatekeeper, bundle ID and version verification: success.
4. Protected CI account authentication and bounded refresh-token-free App session: success.
5. Installed App launch and App-owned device registration as `gha-34664585793-1-macos-app`: success.
6. Action-owned packaged App Agent semantic smoke: success (`route=/index.html`, `screen=messenger`, generation 64).
7. Secondary packaged App Agent Surface Playwright test: success (`1 passed`, 7.5s).
8. Whole-session recording and step screenshots were collected.

The required external complete user journey did **not** occur. The hold waited 1500 seconds and failed at `2026-09-12T01:47:51Z` with `Timed out waiting for @fabushi test complete macOS journey.` Evidence compilation reported `0 successful remote device actions`. The final evidence gate ran with:

- `ACTION_SMOKE_OUTCOME=success`
- `CONTROL_OUTCOME=failure`
- `PLAYWRIGHT_OUTCOME=success`

`Enforce truthful macOS external journey and evidence gate` therefore completed `failure`. There is no acceptable READY_FOR_LOGOUT category note, successful `ci_session_finish`, complete semantic/CI-session trace, or exact `settings-logout` sequence to satisfy FCM-010.13.11.

Evidence was preserved even on failure:

- Artifact ID: `10289026380`.
- Artifact: `fabushi-macos-interactive-evidence-34664585793-1`.
- Size: `151030416` bytes.
- Digest: `sha256:2eb1bc6133d6957c5f44549be840139e933c4c3fdde105246c19446f08182196`.
- Files uploaded: 58.
- Artifact source remains immutable tag `desktop-1.2.56-7ee12b790e18` / exact SHA `7ee12b790e18049d2b9509b0c29128dd2ace690b`.

The execution environment also exposes a dedicated Fabushi dynamic-device MCP, but both its account probe and live-device listing return HTTP 400: `We couldn't connect your account. Please try again.` The generic device namespace likewise does not expose the transient CI App-owned device. This accounts for the absence of external remote calls; substituting a local/historical/KRIS device is forbidden.

- State: **failed / blocking**.
- Required recovery: restore the dedicated Fabushi MCP connection to the protected CI test account, rerun the same immutable exact-source lane, and complete the required semantic categories + READY note + `ci_session_finish` + exact `settings-logout` before the hold timeout.

## Completion decision

- FCM-010.13.8: passed.
- FCM-010.13.9: passed.
- FCM-010.13.10: passed.
- FCM-010.13.11: **failed / blocking**.
- Overall FCM-010.13: **in-progress (fail-closed), not passed**.
- The next CI latency observer / bottleneck-compression round remains intentionally deferred until FCM-010.13.11 succeeds, as required by the user-requested sequence.