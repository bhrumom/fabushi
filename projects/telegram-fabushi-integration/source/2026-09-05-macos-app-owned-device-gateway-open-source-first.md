# 2026-09-05 — macOS App-owned device gateway open-source-first review

- Project: `FAB-P0001 / TFI`
- Work item: `TFI-M11-MACOS-INTERACTIVE-001`
- Canonical baseline re-read before implementation: `main@143c5cf10aed9e6d60810ec6c886acd2c20fa609`
- Latest published macOS test package at planning time: prerelease `v1.2.23`, target `16b56277e2116b73f98f0406a323919de6d7728a`.
- Required ownership model: the installed, logged-in **macOS Fabushi application** owns account-scoped device registration. GitHub Actions supplies the temporary macOS environment and bounded test-account session only. A pre-online Runner, `interactive-runner`, KRIS, or runner-side `fabushi-device-agent.js` is not a device source.

## Existing first-party contracts to reuse

1. `desktop/electron/remote-device-agent-supervisor.cjs` already obtains `feature.auth.deviceAgentSession` from the trusted Rust Host, writes only the current access token to an owner-only file, and starts the **packaged application's** bundled device agent after login.
2. `desktop/electron/main.cjs` and the existing App Agent Surface expose the same six stable semantic tools used by other Fabushi clients: `fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, `assert`.
3. `chatgpt-vps-control/lib/device-gateway.js` remains the single account-scoped WSS device registry and call relay. No macOS-specific registry or second device namespace is introduced.
4. `chatgpt-vps-control/scripts/login-ci-test-account.mjs` plus `export-ci-app-account-session.mjs` already provide the protected CI test-account flow used by iOS. The exported application session is bounded and refresh-token-free.
5. `desktop/playwright.config.ts` already records Playwright video, trace, screenshots-on-failure and HTML reports for Electron E2E.
6. The macOS test-release workflow already publishes signed/notarized/stapled DMG/ZIP/updater assets and release metadata; the interactive test must install the latest published release rather than silently substituting a source build.

## Upstream / platform options reviewed

| Upstream / platform | License / status checked | Potential reuse | Decision |
| --- | --- | --- | --- |
| `microsoft/playwright` | Apache-2.0 | Electron launch, resilient locators, video/trace/HTML evidence | **Reuse existing dependency only.** Keep it as secondary App-level evidence; `@fabushi test` remains the remote semantic control truth. |
| `electron/electron` | MIT | Existing desktop runtime and packaged app lifecycle | **Reuse existing runtime.** No second desktop shell. |
| `actions/setup-node`, `actions/cache`, `actions/upload-artifact` | MIT | Dependency cache and immutable CI evidence upload | **Reuse existing Actions patterns.** Cache only safe dependency/build inputs; never cache account sessions or tokens. |
| Apple `/usr/sbin/screencapture` | macOS first-party system utility | Whole-screen video from before package installation through remote test completion | **Use without adding a dependency.** Current macOS supports `-v`/`-V` video capture. The run fails evidence validation if a non-empty whole-session video is not produced. |
| `appium/appium` | Apache-2.0 | Cross-platform WebDriver automation | **Do not add.** It would create another UI-driver/server lifecycle and duplicate the App Surface truth. |
| `mobile-dev-inc/Maestro` | Apache-2.0 | Declarative UI flows | **Do not add.** It is mobile-oriented and would introduce a second journey truth source. |
| FFmpeg/Homebrew screen-capture stacks | FFmpeg LGPL/GPL depending build; Homebrew packaging varies | macOS display capture/transcode | **Do not add for primary capture.** Native `screencapture` removes dependency/TCC attribution complexity; Playwright already supplies App-level WebM evidence. |

No upstream source code is copied by this task.

## CI / evidence decision

Add one dedicated macOS interactive App workflow. It must:

1. allocate a GitHub-hosted Apple Silicon macOS runner (`macos-15`) because the current test release is arm64;
2. start whole-screen video **before** release resolution/download/install;
3. resolve the newest GitHub prerelease whose release title identifies the macOS test train, persist release JSON, asset name, digest, tag, target SHA and install path;
4. install the exact published ZIP payload into `/Applications/Fabushi.app`, verify code signature/Gatekeeper and record `Info.plist` version/build;
5. authenticate the protected CI test account using the existing helper and export only the bounded app session;
6. launch `/Applications/Fabushi.app/Contents/MacOS/fabushi` with an isolated app-data directory and the bounded session; do **not** launch a standalone runner/device agent;
7. wait until the App-owned supervisor reports device registration, then hold the live App for `@fabushi test` semantic calls;
8. take a screenshot for each completed remote device call and keep the redacted device-call trace;
9. run the existing packaged App Agent Surface Playwright test as a secondary report after the live remote journey, with the CI account/session variables removed so it cannot register a competing device;
10. always upload whole-session video, step screenshots, device-call trace, Playwright report/video/trace, app/system logs, release metadata and machine/human reports on PASS or FAIL;
11. fail closed if the release package, App-owned registration, substantial external semantic call evidence, whole-session video, or evidence upload prerequisites are missing.

## Defect handling

The platform-enablement PR only establishes this truthful macOS test lane. Any product defect found by the first live journey is recorded independently and repaired as one defect per PR. Heavy packaging and complete journeys stay in Actions; PR validation is kept to the narrow contract/unit checks required for the changed defect. After each protected merge, publish a version-comparable macOS test release, test that newest published package again, and write exact SHA/version/run/job/timestamp/links back to the TFI task/evidence ledger.