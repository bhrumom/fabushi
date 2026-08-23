# M8-CALL-001 Evidence Index

- Project: `FAB-P0001` / `TFI`
- Task: `M8-CALL-001`
- Branch: `feat/tfi-miniapp-ai-service-calls`
- Status: `IN_PROGRESS`

## Implementation evidence

- `native/mahayana-messaging/src/miniapp_service_call.rs` — service-call state/input/effect contract；MCP Tool catalog snapshot；DTMF/chat-number → MCP Tool route；natural-language → constrained MCP Tool resolution；catalog 外 Tool 拒绝；`InvokeMcpTool` request/result audit；unit tests。
- `native/mahayana-messaging/src/miniapp.rs` — `ServiceCall` capability and service-call bridge requests/responses；voice/hybrid 要求 `Microphone`。
- `native/mahayana-messaging/src/lib.rs` — public Rust domain export。
- `frontend/packages/mcp-app-sdk/src/types.ts` — existing canonical `McpTool` / `McpToolResult` model used as protocol-alignment reference。
- `frontend/packages/mcp-app-sdk/src/bridge.ts` — existing MiniApp MCP `tools/call` bridge runtime reference。
- `frontend/apps/web/src/app/miniapps/[id]/McpPluginApp.tsx` — existing `tools/list` / `tools/call` production-facing MCP Apps flow reference。
- `decisions/ADR-0008-miniapp-service-call-unified-conversation.md` — architecture decision: MCP is the only MiniApp business execution boundary。

## Key commits in this round

- `fa2a96e953643b49465a2a5de34db9283ead048e` — persist user clarification: all MiniApp phone/chat business execution must go through MCP。
- `89cad5682e6abcb3bb9e23c132bb772db9ea0bba` — refactor Rust service-call contract to MCP-only execution semantics。
- `fe17e70236d5f440924a5152bc05ce97661b218e` — task acceptance redefined around MCP-only execution。
- `a0f82ed050a8d50c8077b95a4af1d25255021244` — ADR-0008 updated with MCP-only invariant and no-fallback rule。
- `11b2c981ee61f853534915518032fec74872cf9a` — product/architecture spec updated for MCP-driven service calls。
- `a6948a8ad40a78c5c15d33adeb88e5f04b0f7b73` — WBS expanded for STT, constrained MCP resolver/executor, composer routing。

## Required acceptance evidence

M8-CALL-001 is not complete until current-head GitHub Actions proves at least:

1. Rustfmt success for `native/mahayana-messaging`。
2. Unit/contract tests success, including:
   - DTMF → exposed MCP Tool；
   - chat numeric input → same DTMF/MCP route；
   - final speech/chat natural language → `ResolveMcpTool`；
   - resolver cannot select unexposed Tool；
   - no matching Tool → `McpCapabilityUnavailable`；
   - unmapped DTMF does not execute anything；
   - ended session rejects input；
   - MCP result audit；
   - DTMF route cannot reference unexposed Tool；
   - MiniApp `ServiceCall + Microphone` permission mapping。
3. Clippy success。
4. Required repository/product/governance checks success。
5. Protected merge and canonical `main` readback before task closure。

## Verification evidence

- Local application build/test: **not run**, prohibited by repository disk-safety policy。
- PR: #2063。
- GitHub Actions current-head CI: pending after MCP-only refactor/doc commits。
- Protected merge / canonical-main verification: pending。

This index must be updated with latest-head workflow run/check IDs and merge SHA before the task can advance to `TESTED`/complete。
