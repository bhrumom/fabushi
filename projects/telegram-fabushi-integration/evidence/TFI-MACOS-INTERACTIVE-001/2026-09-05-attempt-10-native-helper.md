# TFI-MACOS-INTERACTIVE-001 — Attempt 10: v1.2.27 native helper blocker

- Project/task: `FAB-P0001 / TFI` / `TFI-MACOS-INTERACTIVE-001`
- Status: `TESTING`
- Governed release: `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`
- Release workflow: `33975254021` — SUCCESS, including exact protected-main bind, canonical test-tier source gate, build, Developer ID signing, Computer Use staging, package, notarization/stapling, Gatekeeper/package verification, immutable prerelease publication, and release evidence.
- Release ZIP: asset `545990108`, `fabushi-1.2.27-macos-arm64.zip`, SHA-256 `097d6e905a094cb5a9927a91fc2955286a88e8f0e4a2cbf8de5b701cdabdba98`.
- Release evidence artifact: `9972290313`, SHA-256 `261ddd727bddd26a647e273dbd2278884cd4eb746345d153697d29aea71bd325`.
- Canonical release chain: `33975898146` — SUCCESS.
- Interactive run/job: `33975902199` / `101332420780`; workflow source `10b1b2eca2ab50e6909ecbc2bf481747510eefc8`.
- Fresh App-owned device: `gha-33975902199-1-macos-app`.

## Passed gates

Recording started before package installation. Newest-release resolution, exact v1.2.27 install, protected test-account login, bounded App session, App launch, and App-owned gateway registration all passed. `ci_session_status` reported `app-ready` with executable `/Applications/Fabushi.app/Contents/MacOS/fabushi`.

The PR #2378 stable-target regression passed on the real network path: a snapshot exposed stable `test:profile-navigation-trigger` at generation `259`; by action execution the page had advanced to generation `306`, yet the unchanged stable target was safely rebound and invoked successfully.

## Attempt 10 blocker

The profile navigation menu exposes some product navigation entries only as generation-bound refs. `联系人` was found as `g467:17` at generation `467`; before action the page advanced to `494`, so the action correctly failed closed with `stale_app_surface_generation: expected 494, received 467`. Positional refs must remain fail-closed and are not eligible for stable-target rebinding.

The required native accessibility fallback on the same App-owned device then failed before it could inspect the installed Fabushi application:

`Computer elements failed: macos-ax: The file /Users/runner/Applications/Fabushi Computer Control.app does not exist.`

The signed package itself is not missing the helper: the release verifier passed and the packaged runtime resolves the helper under `resources/computer-control/Applications/Fabushi Computer Control.app`. The defect is in `desktop/electron/remote-device-agent-supervisor.cjs`: it selects the embedded MCP runtime but discards the package-derived helper/home environment before spawning `fabushi-device-agent.js`; the direct local MCP therefore falls back to `~/Applications/Fabushi Computer Control.app`.

No contacts/groups/Bot/Mini App/media/settings/update/logout capability after this blocker is claimed. The remote session was explicitly finished so evidence collection and cleanup could complete.

Secondary packaged App Agent Surface Playwright: PASS. Evidence collection/upload and private-session cleanup: PASS. Final external-journey truth gate: FAIL, as required.

Interactive evidence artifact: `9972345831`, `fabushi-macos-interactive-evidence-33975902199-1`, SHA-256 `6e647adb3a6cf0729d99384086ec2edd3c20032e53acc700b9c514ad3cccfc49`.

## Atomic repair contract / next candidate

Branch `fix/tfi-macos-app-owned-native-helper-env-20260905` stages strictly newer macOS test version `1.2.28` while Android/iOS build counters remain unchanged. The repair propagates only package-derived Computer Use environment from `embeddedComputerControlEnvironment()` into the App-owned device agent's direct local MCP:

- `MAHAYANA_COMPUTER_MCP_HOME` -> `CHATGPT_COMPUTER_HOME`
- `MAHAYANA_COMPUTER_MCP_NATIVE_HELPER` -> `CHATGPT_COMPUTER_NATIVE_HELPER`
- `MAHAYANA_COMPUTER_MCP_MAC_APP_DIR` -> `CHATGPT_COMPUTER_MAC_APP_DIR`

The package-derived values override inherited shell values. Account/session/gateway ownership and exact stale-ref semantics are unchanged. A narrow GitHub CI test must prove the App-owned supervisor uses the signed bundled helper before protected merge. Only a governed, strictly newer `v1.2.28` package may be used for Attempt 11.
