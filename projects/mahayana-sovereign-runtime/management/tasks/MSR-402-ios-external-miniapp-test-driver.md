# MSR-402 — iOS external MiniApp test-driver and real E2E

## Identity
- Project: `FAB-P0005` / `MSR` / Mahayana Sovereign Runtime
- Task: `MSR-402`
- Status: `in-progress`
- Source task id: `ios-external-miniapp-e2e-20260810`
- Applied task revision: `2`
- Applied spec digest: `sha256:cca624424090aad55b6a1f92d89c4d97b37fbc2491b862473074ecaf4ad91651`
- Source specification: `.agents/plugins/plugins/chatgpt-auto-confirm/tasks/ios-external-miniapp-e2e-20260810/`

## Objective
Establish the reusable Mahayana-owned automation contract required for the iOS-first external MiniApp journey, then drive the real online `全球法布施` release through the same product core used by normal Fabushi surfaces. The test driver is a control plane only; marketplace, installation, update, conversation, action/tool execution and persistence remain owned by Mahayana CLI/core services.

## Atomic acceptance for the current slice
1. A versioned JSONL contract exposes the required test-driver method names and stable request/response/error shapes.
2. Request lifecycle evidence is correlated through `correlationId`, structured events and bounded diagnostic logs.
3. Sensitive credential-like fields are redacted before diagnostic persistence/return.
4. Business methods are delegated through an explicit product backend and cannot be implemented as protocol-local fake success.
5. A dedicated CLI test-driver entry point exists only for Debug/test builds; Release compilation of that binary fails closed.
6. Contract tests and a GitHub Actions smoke gate verify the above before product-core/iOS adapters are added.

This slice does **not** satisfy the complete task acceptance. In particular, the real Mahayana product backend, secure iOS-local transport/nonce, real online marketplace install/update/chat/action evidence, Simulator scenario and post-main delivery gates remain required.

## Open-source-first startup gate
Reviewed architecture/pattern sources before implementation:
- `ChromeDevTools/devtools-protocol`: adopted the pattern of a versioned command/event control protocol and independently correlated asynchronous evidence. No source code copied.
- `w3c/webdriver-bidi`: adopted bidirectional command/event semantics and explicit protocol errors. No source code copied.
- `appium/appium`: retained as the future iOS UI-driving layer only; Appium/WebDriver state will not become the business source of truth. No source code copied.

Decision: implement a small Fabushi-owned Rust protocol because the product needs Mahayana-specific marketplace/plugin/conversation/action evidence and a compile-time Debug-only boundary. Reusing CDP/WebDriver/Appium wire implementations directly would either bind the domain model to browser automation or create a second business state machine. The reviewed projects therefore inform transport and event semantics, while Mahayana product services remain authoritative.

## Implementation evidence
Branch: `agent/ios-external-miniapp-e2e-r2`

Current code commits:
- `07dcfa9d370edfcbfd7bef3763159c95c67e4ef0` — add `mahayana-test-driver-protocol` crate manifest.
- `53cf3e3bf558e8b405c99948177a535f52a2560f` — versioned requests/responses/events/logs, correlation, redaction, backend delegation and contract tests.
- `45d74a61d2c32b96fe694b4eb662481f7a5df2da` — register Debug-only test-driver binary/feature in `mahayana-cli`.
- `40d779020caf7a0929e3a17e3022de5feb938269` — JSONL stdio test-driver entry point with release compile-time denial.
- `fcaf4ba5e38989e8ed532e86e823bff5f673c918` — register the new protocol crate in the Mahayana workspace.

## Verification plan / evidence
Required for this slice before it can be marked passed:
- `cargo test -p mahayana-test-driver-protocol`
- `cargo check -p mahayana-cli --features test-driver --bin mahayana-test-driver`
- JSONL smoke: `health`, `events.subscribe`, `logs.query`, `shutdown`.
- Release negative: `cargo check --release -p mahayana-cli --features test-driver --bin mahayana-test-driver` must fail with the compile-time security message.
- Git diff/PR/CI evidence for the exact head SHA.

## Remaining task-wide acceptance
- Wire `resetProfile`, test login, real marketplace search/install/update/list, MiniApp open/chat and dynamic actions to Mahayana product/core services without fakes.
- Persist installation receipts and recover authoritative state after process restart.
- Add local-only authenticated iOS Debug/test transport with nonce and Release/Store negative checks.
- Prove `全球法布施` is not prebundled, then use the real online official marketplace/artifact with exact version, digest, signature/provenance/source commit/platform evidence.
- Prove hot update/atomic switch/rollback without host App rebuild.
- Execute deterministic robot chat and all discoverable actions with request/tool/result/conversation/correlation evidence.
- Add clean iOS Simulator CI, semantic UI driver, failure/restart/idempotency cases and retained evidence bundle.
- Complete protected-main merge, canonical-main readback, required post-main package/E2E/Release gates.

## Next action
Wire the first real product-backed methods (`plugin.list` and `marketplace.search`) through existing Mahayana product/runtime APIs and extend contract tests to prove the driver delegates to the same production path rather than a fixture or mock state machine.
