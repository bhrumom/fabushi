# macOS test build product review — 2026-09-03

Build under review: `1.2.14-test.152`, release tag `desktop-mac-test-152-550f644cd6c1`, installed at `/Users/gloriachan/Applications/Fabushi Test.app`.

## Observed blockers

1. The explicitly selected `fabushi test` ChatGPT connector cannot begin device discovery. Both `fabushi_account` and `list_devices` return `400: We couldn't connect your account. Please try again.` The public MCP health and OAuth metadata endpoints respond `200`, so this is an account/OAuth connector-path failure rather than a dead public endpoint.
2. The Mac test artifact is ad-hoc signed. `codesign` reports the outer app as `Identifier=Electron`, `Signature=adhoc`, `TeamIdentifier=not set`; bundled `mahayana-app-host` is also ad-hoc. The installed stable `/Applications/Fabushi.app` and its Host are Developer-ID signed with Team ID `M4Q99K4UR4` and canonical identifiers.
3. While the test build accesses the existing `com.ombhrum.fabushi.auth.v2` Keychain item, macOS presents a SecurityAgent password dialog for `mahayana-app-host`. Leaving the dialog unresolved blocks the Host request channel; refusing the request does not restore the already-timed-out request path.
4. The UI then surfaces repeated `bridge/invoke-failed: Mahayana host request timed out` errors for `feature.info`, `feature.execute`, and `feature.messaging.access.issue`.
5. A harmless Messenger send (`测试：请只回复“OK”`) clears the composer and creates a Mahayana run, but the run remains in planning until the two-minute Host timeout and then fails with `feature.execute` timeout. No usable assistant reply is produced.
6. Settings logout remains disabled as `退出中…` while the Host request times out; the account is not cleared, and restarting the app restores the same authenticated workspace. This blocks the requested clean logout -> test-account login journey.
7. Mini Apps opens but reports `没有找到可安装的 Mini App`. This needs catalog/backend confirmation before it is treated as a standalone marketplace defect, but it blocks current Mini App product review.
8. Canonical avatar identity is still inconsistent for Mahayana: conversation/list/header elements use `peer:conversation:mahayana-ai:agent:assistant`, while Workbench run cards use `bot:mahayana-assistant`. This violates the GBF-805 same-Bot-identity acceptance intent.
9. With no successful Agent run active, the test build still showed sustained Electron GPU/renderer CPU around 18–21% + 10–12% respectively in repeated spot checks, so idle/near-idle energy remains materially high.

## Positive observations

- The packaged app launches and restores the previous Messenger workspace.
- `Research Bot`, `Incident Bot`, group, calls, wallet, settings navigation, and the visible desktop `退出登录` action render.
- Router shows the current Fabushi account as ready and the Host as available, but this status is misleading while Host calls are timing out.
- The test release correctly stays separate from the installed stable app.

## Acceptance impact

The macOS test artifact is not suitable yet for recalibrating formal app-driving E2E because authentication/Host access is blocked by the ad-hoc signing/keychain boundary. Fix or safely isolate the test signing/keychain identity first; then repeat logout -> login -> Agent -> Mini App -> restart checks on the same real Mac before updating formal E2E expectations.
