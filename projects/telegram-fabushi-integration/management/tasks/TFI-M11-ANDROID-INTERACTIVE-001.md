# TFI-M11-ANDROID-INTERACTIVE-001 — Android released-APK interactive release-test loop

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Platform: Android Emulator + signed Native Android GitHub Release APK
- Updated: 2026-09-06
- Canonical baseline: `main@3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`

## Problem boundary

Android already owns `FabushiAppAgentSurface` and the six semantic tools, but canonical main has no installed-App remote-device transport or Android interactive Actions gate. The latest Android published package is also behind canonical version state. Existing Runner gateways and stale devices are not valid substitutes.

## Requirement

After a signed Android GitHub Release APK is published from protected canonical main, GitHub Actions must start evidence recording, install that exact APK, authenticate the protected CI test account, stage only a bounded refresh-token-free session, and let the installed Android App itself register an account-scoped device with `platform=android` and `metadata.kind=github-actions-android-app`.

The interactive device must expose only:

- `fabushi.app.status`
- `fabushi.app.snapshot`
- `fabushi.app.find`
- `fabushi.app.action`
- `fabushi.app.wait`
- `fabushi.app.assert`

No Runner-owned gateway, arbitrary shell execution, JavaScript execution, reflection, fake note evidence, or assertion deletion is allowed.

## Acceptance

1. PR fast gate runs shell/contract validation plus Android Kotlin compilation only; no local/native build or emulator work.
2. The manual Android interactive workflow accepts an exact release tag and release SHA, verifies the tag points at that SHA, downloads the published APK and `SHA256SUMS.txt`, and installs the verified APK without rebuilding it.
3. Recording/logcat starts before installation. Authentication occurs only after installation.
4. The App imports only the validated protected short-lived session in the GitHub-release variant, sets up the shared host before any authenticated host request, and registers its own official WebSocket gateway.
5. `@fabushi test` discovers only the fresh Android device whose metadata binds it to the exact Actions run.
6. All six semantic tools must complete successfully. The larger feature matrix is driven through those tools and ends with a real logout that disconnects the App-owned gateway.
7. The workflow uploads complete video, per-call screenshots, gateway trace, logcat, release/checksum identity, report and diagnostic logs on both success and failure.
8. Any product defect discovered by semantic control receives its own fix PR and project record, followed by a new version/release and rerun.

## Current implementation PR scope

- Android App-owned WebSocket gateway transport.
- GitHub-release-only bounded CI session bootstrap.
- Exact released-APK Android interactive Actions workflow and evidence runner.
- Minimal PR compilation/contract gate.
- No UI semantic-surface behavior change in this task; logged-in surface completeness is intentionally left to evidence-driven follow-up after first live Android device registration.

## 2026-09-06 release-to-interactive self-start follow-up

Live recovery re-read found the Android interactive workflow active but with zero historical runs. The current Android release workflow publishes the signed immutable test APK but does not dispatch the required interactive acceptance lane. The atomic follow-up on `fix/tfi-android-interactive-self-start-20260906` preserves the existing App-owned gateway and six-tool truth contract, adds only the `actions: write` permission needed by the release job, and dispatches the existing Android interactive workflow after successful release publication with the exact release tag and canonical source SHA. Task status remains `IN_PROGRESS` until protected merge, a strictly newer Android release, fresh App-owned Android device discovery, complete six-tool feature-matrix execution, real logout, and complete evidence upload all pass.

## 2026-09-06 Android 1.2.39 retest candidate

After protected merge of PR #2406, canonical main is `b6dc0d009d71c66f1581cba94199e2679bd1eb6d`. The next strictly newer governed Android candidate is `1.2.39` on `release/tfi-android-1-2-39-20260906`. This candidate exists only to publish the post-repair signed Android test APK and exercise the newly connected release-to-interactive App-owned acceptance path. Status remains `IN_PROGRESS` until the version PR is protected-merged, the exact-main Android release succeeds, its self-started interactive run registers a fresh run-bound Android App-owned device, the complete six-tool feature matrix and real logout pass, and the required video/screenshots/trace/logcat/report evidence is verified.

## 2026-09-06 Android 1.2.39 interactive checksum failure

Release `android-v1.2.39-262490741` on `6ea18f731759081a5e64d26ccb10d31d1f720ea6` successfully self-started interactive run `34020127055`, proving the release-to-interactive handoff added by #2406. The run failed before APK install because the interactive script downloaded the APK and `SHA256SUMS.txt` but not the `fabushi-android-update.json` file that the checksum manifest also covers. Artifact `9985225969` preserves the failure evidence. The atomic follow-up `fix/tfi-android-interactive-release-metadata-checksum-20260906` only downloads that immutable metadata asset before checksum verification and locks the order with a contract test. Status remains `IN_PROGRESS`; no Android App-owned device was registered by the failed run, and no old device may be substituted.

## 2026-09-06 Android 1.2.41 retest candidate

After protected merge of checksum correction PR #2410, canonical main is `0d1492d421ca1b7ad5fe5244ddf9057b2d0585ff` at global version `1.2.40`. The next Android retest candidate is `1.2.41` on `release/tfi-android-1-2-41-20260906`. Status stays `IN_PROGRESS` until protected version merge, exact-main release, self-started interactive run, fresh App-owned Android registration, complete external six-tool functional matrix, real logout, and full evidence verification succeed.

## 2026-09-06 authenticated Android Grok surface failure

Release `android-v1.2.41-262490800` self-started interactive run `34020990627`, whose fresh App-owned Android device `gha-34020990627-1-interactive` came online. Real external calls through all six `fabushi.app.*` tools established the first post-login semantic failure: status/snapshot/find/wait/assert remained at `screen=unavailable`, `generation=0`, and action failed `app_surface_element_not_found`. This matches the risk frozen in the original Android App-owned source review: the logged-in `MainActivity` branch renders `GrokMobileShellAndroid`, while semantic publication existed only in legacy `FabushiScreen`. The separate atomic follow-up `fix/tfi-android-authenticated-grok-semantic-surface-20260906` routes the Activity-owned surface into the authenticated Grok shell and Bot chat and publishes bounded native semantics there. Status remains `IN_PROGRESS`; 1.2.41 is not a pass and no old device may substitute for a strictly newer post-fix run.

## 2026-09-06 Android 1.2.42 post-authenticated-surface-fix retest candidate

Authenticated semantic-surface fix PR #2414 merged as `d98e4292d6754c7d3888dcaf497456db03a395b6`. From protected canonical base `d806a734d4f7cf2816520f28a7fc3e9dac5b3849`, the next governed Android test candidate is `1.2.42`. Status remains `IN_PROGRESS` until protected version merge, exact-main immutable Android release, fresh run-bound Android App-owned device registration, all six `fabushi.app.*` tools across the full declared functional matrix, real logout, and complete video/screenshots/trace/logcat/report evidence all pass. No prior run/device can satisfy this gate.

## 2026-09-06 Android 1.2.42 full-home search semantic blocker

Run `34022804599` / fresh device `gha-34022804599-1-interactive` verified the authenticated Grok semantic surface and all six semantic tools, then exposed a new deterministic blocker after `New message` entered full Fabushi home: snapshot generation 38 advertised enabled `home-search-button`, but exact-generation `invoke` returned `app_surface_action_unavailable`. Root cause is a split ownership bug: real `ConversationHome` search state was local and the App-agent publisher emitted the button without an action or semantic search field. Fix scope is limited to the full-home search semantic bridge; acceptance remains blocked pending protected merge, strictly newer Android release, and full retest on a new run-bound App-owned device with complete always-upload evidence.

## 2026-09-06 Android 1.2.44 marketplace semantic-back blocker

Run `34023749387` / fresh App-owned device `gha-34023749387-1-interactive` verified all six semantic tools, Grok search, and the #2422 full-home search repair. The next deterministic blocker occurs after entering `插件市场`: the released semantic surface has no return/close element (`find("返回")` => no matches), even though the real Compose marketplace already renders `返回消息` wired to `onBack`. Fix scope is limited to binding that existing control into the App-owned semantic surface. Acceptance remains blocked pending protected merge, strictly newer Android release, fresh run-bound App-owned device, continued matrix coverage, real logout, and complete always-upload evidence.

## 2026-09-06 Android 1.2.45 remote-MCP async-audit ENOSPC blocker

Run `34025013929` attempt 1 verified release/install/login/App launch but never produced a stable externally discoverable App-owned device. Its always-upload trace repeatedly records `register-sent -> registered -> receive-failed transport_error:EOFException`. During attempt 2 the public MCP health returned HTTP 502; origin `bhrum2` reported root filesystem 100% full and its Node PID changed while host/cloudflared stayed up. Exact source inspection shows the gateway's synchronous-only audit wrapper can leak the rejected Promise from the remote MCP's async `appendFile` audit path on ENOSPC, contradicting the invariant that auditing cannot break the control channel. Fix scope is limited to safely consuming async audit rejection plus a regression test. Production disk space/audit durability must still be recovered before the Android acceptance run can pass.
