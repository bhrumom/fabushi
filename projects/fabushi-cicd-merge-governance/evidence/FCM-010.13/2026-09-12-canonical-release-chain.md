# FCM-010.13 canonical release-chain evidence — 2026-09-12

## Scope and exact source

- Canonical product source SHA for this evidence round: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Immutable Release tag: `desktop-1.2.56-7ee12b790e18`.
- Generation-race controller repair canonical main: `26348bde9091a8bb8cffa864bb911ad70046953e`.
- This record remains fail-closed: FCM-010.13 is not passed until the exact-source installed macOS App-owned full journey and final truthful evidence gate succeed.

## FCM-010.13.8 — PR required Actions

- PR #2530 merged on 2026-09-12.
- PR head `ed0b608717ae585cf73bf6ca3b164cd018750b2f`.
- `CI result` check `103463385262`, run `34661029319`: success.
- State: **passed**.

## FCM-010.13.9 — canonical same-SHA gates and Release

For product source `7ee12b790e18049d2b9509b0c29128dd2ace690b`:

- Electron desktop run `34663960416`: success.
- Native Android + Native iOS run `34663960421`: success.
- Post-main exact-main gate + tested-artifact publisher run `34664490101`: success.
- Published immutable Release ID `387414284`, tag `desktop-1.2.56-7ee12b790e18`.
- `target_commitish` and tag dereference both resolve to `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- macOS asset `fabushi-1.2.56-macos-arm64.zip`, asset ID `558368830`, declared digest `sha256:314225bc49ca203f72cf271e02c85884b6b91ef38638a91f2136f81c25f57e0c`.
- State: **passed**.

## FCM-010.13.10 — automatic immutable-tag dispatch

- Accepted release-chain run `34664577213`.
- Dispatch job `103473806024`: success/not-skipped.
- Immutable-tag dispatch contract remains unchanged.
- State: **passed**.

## Generation-race evidence before repair

Production controller run `34673090393` successfully authenticated through the protected-account production MCP preflight and automatically dispatched exact frozen-source target `34673135503/1`, exact device `gha-34673135503-1-macos-app`.

The controller correctly re-resolved current semantic targets after each stale-generation error. The final sustained churn sequence for a query target advanced `173 -> 177 -> 178 -> 179 -> 180 -> 182 -> 186 -> 189`, then the eighth action attempt failed `stale_app_surface_generation: expected 190, received 189`. Thus the defect was bounded retry-budget exhaustion, not stale generation/ref reuse.

Controller failure artifact `fcm-010-13-11-external-controller-34673135503-1`, ID `10291612205`, digest `sha256:3f3cd0d2c1e5c464adf5bcc0ee3008816af5107ddbb0b0510605ad68af325f63`.

## Generation-race repair — PR #2547

PR #2547 retained the existing fail-closed semantic re-resolution algorithm and made the minimal convergence change:

1. default generation-sensitive retry budget `8 -> 32`;
2. existing deterministic `find=95 -> action requires 96` test retained;
3. deterministic sustained-churn regression added, forcing eight stale action attempts, requiring a new semantic `find` on each retry, and proving the ninth action uses generation/ref `103/g103`;
4. generation helper added to external-controller workflow path trigger and syntax check;
5. exact device ID, frozen source SHA, immutable tag, 27 categories and final READY/finish/fresh-snapshot/logout ordering unchanged.

Required PR CI and `External controller contract` passed. GitHub native auto-merge entered the protected merge queue and landed #2547 as `main@26348bde9091a8bb8cffa864bb911ad70046953e`.

## Fresh post-merge production target

Controller run `34673949330` started automatically from canonical repair SHA `26348bde9091a8bb8cffa864bb911ad70046953e`:

- controller contract: success;
- protected-account production MCP preflight: success;
- immutable Release provenance: success;
- automatically dispatched target `34673991774/1`;
- target source `7ee12b790e18049d2b9509b0c29128dd2ace690b`;
- target branch/tag `desktop-1.2.56-7ee12b790e18`;
- exact App-owned device `gha-34673991774-1-macos-app`.

Target `34673991774` proved the installed-package path remains real:

1. exact Release download/digest and install: success;
2. arm64/signature/Gatekeeper/bundle/version verification: success;
3. protected account login: success;
4. App-owned device registration: success;
5. Action-owned packaged semantic smoke: success (`generation=83`);
6. secondary packaged App Agent Surface Playwright: success (`1 passed`, 8.5s);
7. live generation-sensitive actions crossed the previous retry-budget failure point and both self-hosted test channels were created;
8. evidence compiler recorded **56 successful remote device actions**.

This is production proof that the generation-race repair itself works: stale actions are re-resolved against fresh semantic targets and can converge beyond the old eight-attempt limit.

## New downstream failure after generation repair

The journey subsequently failed on a different semantic identity:

`semantic target not found: {"agentId":"test:peer-legacy:conversation:mahayana-ai:agent:assistant"}`

The controller wrote a `TFI_MACOS_FULL_JOURNEY FAIL ...` note and called `ci_session_finish`. It did not emit `READY_FOR_LOGOUT PASS`, did not take the required success-path fresh snapshot after finish, and did not invoke exact `settings-logout`.

Target run `34673991774` completed `failure`. The final truthful evidence gate also completed `failure` with Action smoke success, external control failure and Playwright success. This is expected fail-closed behavior.

## Failure artifact and retained evidence

- Artifact: `fabushi-macos-interactive-evidence-34673991774-1`.
- Artifact ID: `10291553529`.
- Size: `160229449` bytes.
- Digest: `sha256:fde3ea98c320218c4716a049bffeeb48a5a27020e23b5b3e0cf155414bf5b0e8`.
- Files uploaded: 112.
- Retained classes: device-call trace, generated regression, App/system logs, Release/source metadata, step screenshots, Playwright report and Playwright trace.

The workflow started its whole-session recorder before install as intended, but the uploaded artifact contains no `macos-session.mov`. `screencapture.log` reports `IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver`. Therefore the mandatory full-session video gate is also not satisfied and must not be claimed as present.

## Blocker transition

The old dedicated-MCP HTTP-400 blocker is closed: production preflight is green, exact run-owned device discovery works and nonzero real remote actions are proven. The generation-race blocker is also closed for this round through PR #2547 plus fresh production behavior.

The current FCM-010.13.11 blockers are now:

1. missing legacy assistant semantic projection `test:peer-legacy:conversation:mahayana-ai:agent:assistant`;
2. missing whole-session macOS video artifact.

## Completion decision

- FCM-010.13.8: **passed**.
- FCM-010.13.9: **passed**.
- FCM-010.13.10: **passed**.
- Generation-race repair: **passed / production verified**.
- FCM-010.13.11 overall: **failed / blocking**.
- FCM-010.13 overall: **in-progress / fail-closed**.

The latency-observer / bottleneck-compression round remains intentionally deferred. Per the required sequence it starts only after a fresh production target simultaneously proves all 27 categories, `READY_FOR_LOGOUT PASS`, successful `ci_session_finish`, fresh App snapshot, exact `settings-logout`, target success, truthful evidence success and complete video/trace/log/screenshots/artifact/digest.
