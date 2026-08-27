# M8-WEBMCP-001 Evidence — MiniApp WebMCP Runtime

Status: **IN_PROGRESS — PR #2169 pre-merge verification**

## Implementation evidence

- WebMCP SDK adapter: `frontend/packages/mcp-app-sdk/src/webmcp.ts`
- WebMCP SDK contract tests: `frontend/packages/mcp-app-sdk/test/webmcp.test.ts`
- Hosted MiniApp projection: `frontend/apps/web/src/app/miniapps/[id]/WebMcpMiniAppAdapter.tsx`
- Hosted MiniApp route integration: `frontend/apps/web/src/app/miniapps/[id]/page.tsx`
- Marketplace/WebMCP admission policy: `ai-backend/src/miniapp_webmcp_policy.js`
- Admission tests: `ai-backend/test/miniapp_webmcp_policy.test.js`
- Desktop installed MiniApp bridge: `desktop/src/miniapp-webmcp-host.ts`
- Rust local runtime call: `third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs` (`runtime.call`)
- Android local-first WebMCP surface: `mobile/android/app/src/main/java/com/ombhrum/fabushi/MiniAppWebMcpSurface.kt`
- iOS local-first WebMCP surface: `mobile/ios/Fabushi/MiniAppWebMcpSurface.swift`
- Cross-platform version baseline: `app-version.json` = 1.0.4, build/version codes = 2; desktop/mobile package metadata and iOS project metadata aligned.

## Open-source-first / standards evidence

- Web Machine Learning Community Group WebMCP draft and canonical `webmachinelearning/webmcp` repository were inspected before finalizing the adapter.
- The adapter follows the 2026-08-26 draft shape: `document.modelContext.registerTool(tool, { signal })`, `getTools()`, `executeTool(RegisteredTool, input)`, abort-based unregistration, and current WebMCP annotations.
- OpenAI Site Tools/WebMCP product model and MCP/MCP Apps were reviewed for the split between page-scoped foreground tools and durable backend/runtime execution.
- No upstream source code was copied; Fabushi adapts the standard to its existing Tool Contract, MCP HTTP client, Electron bridge, and Rust Host.

## Pre-merge CI evidence

Earlier PR head `92839fbef2ddb747cf3329663aee138a7a55f15a` exposed two deterministic preflight defects:

1. Electron architecture gate: `canonical=1.0.4 desktop=1.0.4 mobile=1.0.3` — fixed by aligning `mobile/package.json` to 1.0.4.
2. Mahayana/native fast path: `cargo fmt --check` requested a single import wrap in `mahayana-app-host` — fixed in commit `35634dcd739ad33702cfb55e716d94aa081c4b3a`.

Current PR head and workflow results must be re-recorded here after all required checks complete. A green PR is not completion: this task remains IN_PROGRESS until protected-main merge, canonical-main readback, required packaged E2E evidence, and GitHub Release publication are all verified.

## Required closure evidence still pending

- Final required PR checks on the latest PR head.
- Protected `main` merge SHA and canonical readback.
- Exact-main Electron packaged E2E screenshots/video/trace/reports.
- Exact-main Android and iOS simulated-user evidence bundles.
- GitHub Release 1.0.4 tag/target SHA/assets and updater-compatible desktop metadata.
