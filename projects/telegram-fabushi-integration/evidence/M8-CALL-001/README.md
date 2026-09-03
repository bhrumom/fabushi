# M8-CALL-001 Evidence Index

- Project: `FAB-P0001` / `TFI`
- Task: `M8-CALL-001`
- Branch: `feat/tfi-miniapp-ai-service-calls`
- Status: `TESTED / COMPLETED`

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
- `1c1a479eb93be7e21becaa2211463cb6f97b8a06` — latest-main conflict-resolution integration head used for final current-head checks。

## Acceptance evidence

All M8-CALL-001 acceptance gates are satisfied for the atomic core-contract slice:

1. Rustfmt success for `native/mahayana-messaging`。
2. Unit/contract tests success, including DTMF → exposed MCP Tool、chat numeric parity、speech/chat resolver、unexposed Tool rejection、no-match unavailable、terminal-state rejection、MCP result audit and permission mapping。
3. Clippy success。
4. Required repository/product/governance checks success。
5. Protected merge and canonical `main` readback completed。

## Final GitHub Actions evidence

Final PR head: `1c1a479eb93be7e21becaa2211463cb6f97b8a06`.

- Mahayana fast checks `32969707544` — SUCCESS
- Fabushi self-hosted messaging `32969707602` — SUCCESS
- Messaging Product Gate `32969707606` — SUCCESS
- CI `32969707626` — SUCCESS
- Developer Fiat Commerce `32969707538` — SUCCESS
- Project portfolio governance `32969707591` — SUCCESS
- Explicit automerge `32969707671` — SUCCESS

## Merge and canonical-main verification

- PR: #2063
- Protected merge SHA: `1f406461c01ac9ace5e187fd8b9a0e2c63cbcb5d`
- Merge timestamp: `2026-08-26T12:42:42Z`
- Canonical `main` HEAD readback: `1f406461c01ac9ace5e187fd8b9a0e2c63cbcb5d`
- Canonical source readback: `native/mahayana-messaging/src/miniapp_service_call.rs`
- Canonical source blob: `d6f3f503c1bccde38408ce507b9342717813b3ec`
- WBS readback includes M8.T08–T11 without rolling back later M8 marketplace/project-state work.
- Local application build/test: **not run**, per repository disk-safety policy; GitHub Actions current-head checks are the authoritative verification source.

M8-CALL-001 may therefore advance to `TESTED / COMPLETED`. STT、real MCP Host resolver/executor、composer routing、media transport and UI remain separate follow-up tasks and are not implied complete by this closure.
