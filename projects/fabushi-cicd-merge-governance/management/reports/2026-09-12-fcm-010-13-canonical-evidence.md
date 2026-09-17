# 2026-09-12 — FCM-010.13 canonical evidence round

## Result

FCM-010.13 remains **in-progress / fail-closed**. FCM-010.13.8, .9 and .10 stay objectively passed on exact product source `7ee12b790e18049d2b9509b0c29128dd2ace690b`; they were not redone in the generation-race round. The current round did objectively repair and production-verify the generation-sensitive action race, but FCM-010.13.11 still fails later on a newly exposed semantic target plus missing whole-session video evidence.

## Previously accepted immutable-source chain

- PR #2530 required CI: `CI result` run `34661029319` / check `103463385262` succeeded.
- Exact product source: `7ee12b790e18049d2b9509b0c29128dd2ace690b`.
- Electron desktop run `34663960416`: success.
- Native Android + Native iOS run `34663960421`: success.
- Post-main exact-main gate + tested-artifact publisher `34664490101`: success.
- Published immutable Release: `desktop-1.2.56-7ee12b790e18`, target/tag `7ee12b790e18049d2b9509b0c29128dd2ace690b`, macOS ZIP `fabushi-1.2.56-macos-arm64.zip`, declared digest `sha256:314225bc49ca203f72cf271e02c85884b6b91ef38638a91f2136f81c25f57e0c`.
- Automatic release chain `34664577213`, dispatch job `103473806024`: success/not-skipped.
- FCM-010.13.8-.10: **passed**.

## Generation-race diagnosis and repair

Production controller `34673090393` had already restored MCP connectivity and fresh semantic resolution, but target `34673135503/1` exhausted the old eight-attempt generation-sensitive retry budget after repeated fresh re-resolution. The last observed chain was `173 -> 177 -> 178 -> 179 -> 180 -> 182 -> 186 -> 189`, followed by `stale_app_surface_generation: expected 190, received 189`.

PR #2547 made the narrow repair without changing the product source/tag/device/27-category/final-logout contract:

- bounded default retry budget `8 -> 32`;
- retained deterministic `find=95 -> expected 96` regression;
- added deterministic eight-stale churn regression proving every stale action re-runs semantic `find` and eventually acts with the latest generation/ref;
- included the helper in the controller workflow path trigger and syntax check.

Required CI and `External controller contract` passed. PR #2547 entered the protected merge queue and landed as `main@26348bde9091a8bb8cffa864bb911ad70046953e`.

## Fresh production proof after #2547

Controller run `34673949330` started automatically from canonical `main@26348bde9091a8bb8cffa864bb911ad70046953e`.

- Controller contract: success.
- Protected-account production MCP preflight: success.
- Immutable Release provenance: success.
- Automatically dispatched target: `34673991774`, attempt `1`.
- Target source/tag: `7ee12b790e18049d2b9509b0c29128dd2ace690b` / `desktop-1.2.56-7ee12b790e18`.
- Exact App-owned device: `gha-34673991774-1-macos-app`.
- Release install/signature/Gatekeeper/version checks: success.
- Protected account login and App-owned registration: success.
- Action-owned semantic smoke: success (`generation=83`).
- Secondary packaged App Agent Surface Playwright: success (`1 passed`, 8.5s).
- Device-call evidence compiler: **56 successful remote device actions**.

The live controller crossed the exact area that had exhausted the old generation budget. Multiple stale actions were freshly re-resolved and both self-hosted test channels were created. No stale-generation reuse or retry-budget exhaustion recurred. The generation-race subproblem is therefore **production-verified fixed**.

## New truthful failure after the generation fix

The journey then failed on a distinct semantic projection:

`semantic target not found: {"agentId":"test:peer-legacy:conversation:mahayana-ai:agent:assistant"}`

The failure path wrote a `TFI_MACOS_FULL_JOURNEY FAIL ...` note and called `ci_session_finish`. Because the 27-category journey was incomplete, there was no `READY_FOR_LOGOUT PASS`, no success-path fresh App snapshot after finish, and no exact `settings-logout` action.

Target `34673991774` therefore completed `failure`. `Enforce truthful macOS external journey and evidence gate` also completed `failure` with `ACTION_SMOKE_OUTCOME=success`, `CONTROL_OUTCOME=failure`, `PLAYWRIGHT_OUTCOME=success`. This is correct fail-closed behavior and is not acceptance evidence for FCM-010.13.11.

## Retained evidence and video deficiency

Failure evidence artifact:

- name `fabushi-macos-interactive-evidence-34673991774-1`
- ID `10291553529`
- size `160229449` bytes
- digest `sha256:fde3ea98c320218c4716a049bffeeb48a5a27020e23b5b3e0cf155414bf5b0e8`
- 112 uploaded files.

Retained evidence includes device-call trace, generated regression, application/system logs, source/Release metadata, step screenshots, Playwright report and Playwright trace. The whole-session recorder step started, but `macos-session.mov` is absent from the artifact; `screencapture.log` contains `IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver`. Therefore the mandatory full-session video requirement is also unsatisfied.

## Current decision and sequence

- Historical MCP HTTP-400 blocker: **closed / obsolete**.
- Generation-sensitive stale App Surface race: **fixed and production verified**.
- FCM-010.13.11: **failed / blocking**, now on missing legacy-assistant semantic projection plus missing whole-session MOV.
- FCM-010.13: **in-progress / fail-closed**.
- FCM-010.13.8-.10: remain **passed**.
- CI latency observer: **not rerun yet by design**. The user-required order says it runs only after FCM-010.13.11 and FCM-010.13 are fully passed.

The next atomic round should not reopen the generation-race implementation without new evidence. It should close the two newly isolated blockers and then run a fresh exact frozen-source production target through all 27 categories, READY -> finish -> fresh snapshot -> exact logout, target success, truthful evidence success, and complete video/trace/log/screenshots/artifact/digest.
