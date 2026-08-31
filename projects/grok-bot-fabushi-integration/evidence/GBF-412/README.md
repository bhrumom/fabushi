# GBF-412 evidence ledger

Evidence is accepted only when tied to an exact repository SHA, workflow run/job, platform, application version and timestamp.

## Live baseline — 2026-08-31

- Fabushi MCP account label: `fabushi_mcp_ci_test`
- Account id: `197915874789377`
- Discovered device: `gha-33346933085-1-interactive`
- Workflow: `Fabushi account interactive Runner MCP`
- Run id: `33346933085`
- Runner source SHA: `5260646f6c89c09a402719b0b5bc99de352c3e93`
- Dynamic tool count: `25`
- Tool schema version: `26bb5081f843df6af1f1b2e296b0d3c170916eae6ceb6584842dc26a1192a555`
- Remote tool schema lookup: `fabushi.app.status` available in catalog.
- Remote call result: App MCP unavailable because the installed/running desktop process was not publishing a surface.
- CI session status at observation: `starting`, `appReady=false`.

This baseline proves account-scoped live discovery and dynamic tool forwarding, while exposing the exact remaining packaged-App-MCP failure that GBF-412 must close.

## Required future bundles

1. `node-protocol/`: signed identity and mutation-rejection test reports.
2. `gateway/`: account isolation, reconnect, lease, path and call-routing reports.
3. `electron/`: packaged desktop launch, mesh registration, App MCP and Computer Use evidence.
4. `android/`: APK, emulator recording, screenshots, instrumentation report and logcat.
5. `ios/`: app/ipa build provenance, Simulator recording, screenshots and `.xcresult`.
6. `live-runner/`: test-account device listing, tool description/call traces and workflow URL.
7. `post-main/`: exact-main package/E2E and release traceability.

No secret, bearer credential, private node key, cookie or sensitive UI value may be copied into this directory.
