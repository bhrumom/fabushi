# TFI-MACOS-INTERACTIVE-001 evidence ledger

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Status: `TESTING`
- Canonical baseline at enablement start: `143c5cf10aed9e6d60810ec6c886acd2c20fa609`
- Current canonical `main` re-read during enablement: `f6f2bbfc096e62dd42732a64e1a89745e202803d`
- Latest published macOS test package through Attempt 6: `v1.2.23`, target `16b56277e2116b73f98f0406a323919de6d7728a`

## Attempt ledger

### Attempt 1 — infrastructure FAIL before release install

- Workflow source SHA: `a059000c41985f0f8224a222f1a4c234072343a2`
- Run / job: `33969808918` / `101316194394`
- Started / completed: `2026-09-05T13:45:16Z` / `2026-09-05T13:46:49Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33969808918
- Evidence artifact: `fabushi-macos-interactive-evidence-33969808918-1`, artifact `9970589596`, SHA-256 `70b73696161916f1b43dce315b1872f2ddf9db7d32c052a9994e344edf028a8f`
- Release-under-test intent: newest published macOS test prerelease; product installation was never reached.
- Result: **infrastructure FAIL**, not a product FAIL. The new ownership/evidence static contract incorrectly matched forbidden-runner prose and private-session cleanup text. Final truth gate failed; always-evidence upload succeeded. No Fabushi device was registered.

### Attempt 2 — infrastructure FAIL before release install

- Workflow source SHA: `0f0e55d7bbb33d7bb55b7ceb5d58e020938c9ec7`
- Run / job: `33969872078` / `101316386904`
- Started / completed: `2026-09-05T13:46:36Z` / `2026-09-05T13:47:46Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33969872078
- Evidence artifact: `fabushi-macos-interactive-evidence-33969872078-1`, artifact `9970602778`, SHA-256 `80ea859c0398c3b707178156fca48115e43f2a429dfe010c753ece625ea3b413`
- Result: **infrastructure FAIL**, not a product FAIL. Static evidence contract still expected `macos-session.mov` inside the collection step although recording correctly starts earlier. Final truth gate failed; always-evidence upload succeeded. No Fabushi device was registered.

### Attempt 3 — infrastructure FAIL at exact published ZIP install

- Workflow source SHA: `a6bf544a12d48a140e7801f95a7518cf6a51258f`
- Run / job: `33969930227` / `101316512352`
- Started / completed: `2026-09-05T13:47:48Z` / `2026-09-05T13:49:28Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33969930227
- Release: `v1.2.23` -> `16b56277e2116b73f98f0406a323919de6d7728a`; asset `fabushi-1.2.23-macos-arm64.zip` (`545705797`)
- Evidence artifact: `fabushi-macos-interactive-evidence-33969930227-1`, artifact `9970626168`, SHA-256 `00e940e9bb26fb01e6a42bb049bfd499db3445ea6f45a3a467cafb4f634026c6`
- Result: **infrastructure FAIL**, not a product FAIL. Release resolution/download/digest gate passed, then macOS install discovery used GNU `find -maxdepth`, which is not valid on the hosted macOS BSD `find`. Login/App registration were correctly skipped. Whole-session video and FAIL evidence were preserved; no Fabushi device was registered.

### Attempt 4 — infrastructure FAIL exposes release bundle casing

- Workflow source SHA: `09c0568ba3a63108fb980adba41d1e6f0592c1d6`
- Run / job: `33970164893` / `101317137286`
- Started / completed: `2026-09-05T13:52:44Z` / `2026-09-05T13:54:04Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33970164893
- Release: `v1.2.23` -> `16b56277e2116b73f98f0406a323919de6d7728a`; asset `fabushi-1.2.23-macos-arm64.zip` (`545705797`)
- Evidence artifact: `fabushi-macos-interactive-evidence-33970164893-1`, artifact `9970688517`, SHA-256 `b446d24f38efc93e3127c488c872390ea30dbc2a73377f91b8e6030411572dd5`
- Artifact archive-layout evidence: the exact release ZIP contains top-level `fabushi.app/Contents/MacOS/fabushi`; the lane incorrectly assumed case-sensitive `Fabushi.app` while looking for the source bundle.
- Result: **infrastructure FAIL**, not a product FAIL. Recording, static ownership contract, release resolution/download/digest and secondary evidence collection passed; login/App registration were correctly skipped because install identity discovery failed. No Fabushi device was registered.

### Attempt 5 — infrastructure FAIL at protected account handoff

- Workflow source SHA: `93a5cd5d0f416b5a8893cb4f931c527f372b1207`
- Run / job: `33970295856` / `101317481633`
- Started / completed: `2026-09-05T13:55:31Z` / `2026-09-05T13:57:23Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33970295856
- Release: `v1.2.23` -> `16b56277e2116b73f98f0406a323919de6d7728a`; asset `fabushi-1.2.23-macos-arm64.zip` (`545705797`)
- Install verification: PASS — one top-level `fabushi.app` copied to `/Applications/Fabushi.app`; Mach-O arm64, `codesign --verify`, Gatekeeper assessment, bundle id `com.ombhrum.fabushi`, installed version/build `1.2.23 / 1.2.23` all passed.
- Secondary packaged App Agent Surface Playwright: PASS (`1 passed`).
- Failure: `login-ci-test-account.mjs` rejected `DEVICE_ID=gha-33970295856-1-macos-app` with `DEVICE_ID must be the protected interactive Runner id.` This is a legacy account-helper identity guard, not a product journey failure. App launch/registration were correctly skipped; no macOS Fabushi device was registered.
- Evidence artifact: `fabushi-macos-interactive-evidence-33970295856-1`, artifact `9970733917`, SHA-256 `82739298fb775ea21cc637f0be0c4254b5fc94498878e46b328c8d3c128f917a`, size `138476115` bytes, https://github.com/bhrumom/fabushi/actions/runs/33970295856/artifacts/9970733917
- Resolution: protected account login/export/session parsing now accept the bounded App-owned `gha-<run>-<attempt>-macos-app` identity while preserving legacy CI wire fields only for compatibility. Those fields do not own or register the device gateway; the installed App remains the only registration owner.

### Attempt 6 — released App FAIL before App-owned gateway registration

- Workflow source SHA: `23493ebf2aeb59b9ea016db0333120b4ed17d559`
- Run / job: `33970506757` / `101318141899`
- Started / completed: `2026-09-05T14:00:15Z` / `2026-09-05T14:04:38Z`
- Run: https://github.com/bhrumom/fabushi/actions/runs/33970506757
- Release: `v1.2.23` -> `16b56277e2116b73f98f0406a323919de6d7728a`; asset `fabushi-1.2.23-macos-arm64.zip` (`545705797`)
- Install verification: PASS — exact published package, Mach-O arm64, code signing, Gatekeeper, bundle id `com.ombhrum.fabushi`, version/build `1.2.23 / 1.2.23`.
- Protected account login/export: PASS for App-owned `DEVICE_ID=gha-33970506757-1-macos-app`; refresh-token-free bounded application session created successfully.
- App launch: PARTIAL PASS — the installed App emitted `fabushi.app-agent-surface.ready`, proving the packaged semantic loopback surface started, but the Mahayana host channel then failed with `EPIPE`; after 120 seconds the App had not emitted `controllable device online` and no macOS device appeared in `@fabushi test`.
- Root cause: published source `16b56277e2116b73f98f0406a323919de6d7728a` validates CI application sessions with `device_id.ends_with("-interactive")` in `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs`. The App-owned `gha-...-macos-app` identity is therefore rejected before `RemoteDeviceAgentSupervisor` can spawn the App-owned gateway agent. This is an account-session compatibility defect; it is not permission to fall back to a Runner/KRIS/interactive-runner device.
- `@fabushi test` journey: correctly `not-run`; zero device actions and zero journey notes because no valid macOS App device was registered.
- Secondary packaged App Agent Surface Playwright: PASS (`1 passed`).
- Evidence artifact: `fabushi-macos-interactive-evidence-33970506757-1`, artifact `9970831215`, SHA-256 `3cd50173b2264fc8fb15aa5c0ad8f51343535a089875cadd9009d314ae11c554`, size `138664631` bytes, https://github.com/bhrumom/fabushi/actions/runs/33970506757/artifacts/9970831215
- Resolution plan: merge the truthful macOS test-lane enablement through protected `main`, then fix this independent Rust session-validator defect in its own PR, publish a strictly newer macOS prerelease, and retest only the new release.

## Evidence rules

A GitHub release upload is not proof of interaction. An online GitHub runner is not a Fabushi device. Evidence is valid only when the installed macOS Fabushi App has logged into the protected test account, registered itself through the account-scoped device gateway, been discovered by `@fabushi test`, and preserved the required video/screenshots/trace/reports/logs on both PASS and FAIL.

Infrastructure failures before App-owned registration are recorded here but are never counted as a full product journey PASS. The live feature journey begins only after the exact published App is successfully installed, logged in, App-registered, and handed to `@fabushi test`.
