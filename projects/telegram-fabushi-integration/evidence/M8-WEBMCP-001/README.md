# M8-WEBMCP-001 Evidence — MiniApp WebMCP Runtime

Status: **TESTING / IN_PROGRESS — PR #2169 final pre-merge verification**

## Implementation evidence

- WebMCP SDK adapter: `frontend/packages/mcp-app-sdk/src/webmcp.ts`
- WebMCP SDK contract tests: `frontend/packages/mcp-app-sdk/test/webmcp.test.ts`
- Hosted MiniApp projection: `frontend/apps/web/src/app/miniapps/[id]/WebMcpMiniAppAdapter.tsx`
- Hosted MiniApp route integration: `frontend/apps/web/src/app/miniapps/[id]/page.tsx`
- Marketplace/WebMCP admission policy: `ai-backend/src/miniapp_webmcp_policy.js`
- Admission tests: `ai-backend/test/miniapp_webmcp_policy.test.js`
- Desktop installed MiniApp bridge: `desktop/src/miniapp-webmcp-host.ts`
- Desktop WebMCP simulated-user assertion: `desktop/e2e/miniapp-bot-parity.spec.ts`
- Rust local runtime call: `third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs` (`runtime.call`)
- Android local-first WebMCP surface: `mobile/android/app/src/main/java/com/ombhrum/fabushi/MiniAppWebMcpSurface.kt`
- Android instrumentation: `mobile/android/app/src/androidTest/java/com/ombhrum/fabushi/FabushiScreenTest.kt`
- iOS local-first WebMCP surface: `mobile/ios/Fabushi/MiniAppWebMcpSurface.swift`
- iOS UI journey: `mobile/ios/FabushiUITests/FabushiUITests.swift`
- Cross-platform version baseline: `app-version.json` = 1.0.4, build/version codes = 2; desktop/mobile package metadata and iOS project metadata aligned.

## Open-source-first / standards evidence

- Web Machine Learning Community Group WebMCP draft and canonical `webmachinelearning/webmcp` repository were inspected before finalizing the adapter.
- The adapter follows the 2026-08-26 draft shape: `document.modelContext.registerTool(tool, { signal })`, `getTools()`, `executeTool(RegisteredTool, input)`, abort-based unregistration, and current WebMCP annotations.
- OpenAI Site Tools/WebMCP product model and MCP/MCP Apps were reviewed for the split between page-scoped foreground tools and durable backend/runtime execution.
- No upstream source code was copied; Fabushi adapts the standard to its existing Tool Contract, MCP HTTP client, Electron bridge, and Rust Host.

## Security / lifecycle evidence

- Desktop uses a per-document random nonce and never exposes host-wide runtime inventory directly; tools are intersected with the current MiniApp Tool Contract before WebMCP projection.
- Android Native WebMCP bridge returns an error unless the active document is the local MiniApp pseudo-origin; Hosted fallback cannot call local Rust through that bridge.
- iOS WKScriptMessage handling requires the active WKWebView URL to be the local MiniApp pseudo-origin; Hosted fallback messages are rejected.
- Write/destructive Tool calls retain host/native confirmation on desktop/Android/iOS.
- Page teardown aborts WebMCP registration; Rust runtime shutdown remains an explicit `runtime.stop` lifecycle operation, so closing UI does not implicitly terminate background work.

## Pre-merge implementation-head CI evidence

Earlier PR head `92839fbef2ddb747cf3329663aee138a7a55f15a` exposed deterministic preflight defects that were fixed before the green implementation point:

1. Electron architecture gate: `canonical=1.0.4 desktop=1.0.4 mobile=1.0.3` — fixed by aligning `mobile/package.json` to 1.0.4.
2. Mahayana/native fast path: `cargo fmt --check` requested a single import wrap in `mahayana-app-host` — fixed.
3. Exact PR patch audit found an unrelated accidental `MAHAYANA_DOCKER_BIN` → `DOCKER_PATH` edit during a whole-file Rust update — restored before acceptance.
4. Electron TypeScript found a duplicate `window.mahayana` declaration — removed so the bridge reuses canonical `MahayanaElectronBridge`.

Implementation head `b965db5686521fc3dcc4592a293950aa35e542a7` then passed all observed PR workflows:

| Workflow | Run | Result |
|---|---:|---|
| CI | 33037215956 | SUCCESS |
| Electron desktop quality gate | 33037215849 | SUCCESS |
| Mahayana fast checks | 33037215841 | SUCCESS |
| Messaging Product Gate | 33037215905 | SUCCESS |
| Native mobile catch-all | 33037216132 | SUCCESS |
| Mahayana Vendor Isolation | 33037215878 | SUCCESS |
| GBF security closure | 33037215815 | SUCCESS |
| Developer Fiat Commerce | 33037215869 | SUCCESS |
| Project portfolio governance | 33037215819 | SUCCESS |
| Douyin Batch Downloader MiniApp | 33037215821 | SUCCESS |
| Explicit automerge | 33037215965 | SUCCESS |

The CI `MCP plugin contracts` job executes `npm test` inside `frontend/packages/mcp-app-sdk`, so the new WebMCP contract tests are part of actual CI evidence rather than source-only tests.

## Final pre-merge gate

The project-record synchronization commits after `b965db...` intentionally generate a new PR head. The final head must independently re-pass required checks before PR #2169 is moved from Draft to Ready and merged through protected `main`. The green implementation head is evidence of the code implementation, not permission to reuse stale checks for a later head.

## Required closure evidence still pending

- Final required PR checks on the latest project-governance head.
- Protected `main` merge SHA and canonical readback.
- Exact-main Electron packaged E2E screenshots/video/trace/reports tied to the accepted SHA/version/workflow.
- Exact-main Android emulator screenshots/video/instrumentation/log evidence.
- Exact-main iOS Simulator screenshots/video/`.xcresult`/debug evidence.
- GitHub Release 1.0.4 tag/target SHA/assets and updater-compatible desktop metadata from the accepted build lineage.
- A docs-only protected follow-up PR that records the post-main delivery/release evidence and marks M8-WEBMCP-001 complete; until that is merged this evidence record remains `IN_PROGRESS`.
