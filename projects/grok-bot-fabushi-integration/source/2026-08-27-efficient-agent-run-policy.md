# 2026-08-27 — Efficient Agent run policy from Grok Bot operating guidance

## User request

Review Eric Zakariasson's X post `2092642631344161258` together with `bhrum/grok-bot-0.18-reconstructed`, determine how the useful operating pattern maps to the reconstructed implementation, and bring the useful behavior into Fabushi/Mahayana.

## External operating guidance

The indexed X post recommends three concrete ways to make long-running Grok Bot plans more efficient:

1. Prefer event triggers (for example Slack/GitHub/reaction events) when possible instead of waking on a cron when nothing changed.
2. Ask the agent to notify the human as soon as it cannot make further progress or is stalled.
3. Prefer connectors over browser automation when possible.

Related Grok Bot guidance separates reusable HOW (skills) from WHEN (routines), recommends narrow triggers and evidence, and keeps high-impact actions behind approval.

## Reconstructed-source findings

Pinned reference remains `bhrum/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634` per the existing GBF clean-room boundary.

Focused source inspection:

- `source/node-agent-coordinator/routed-mcp-bridge.ts` exposes plugin tools through one provider-neutral MCP bridge. Tool discovery is centralized and each tool is annotated with read-only/destructive/idempotent/open-world hints before models see it.
- `source/node-agent-coordinator/inference-router.ts` keeps one transcript/queue while routing different model providers through the same remote tool execution boundary. Claude uses the loopback MCP bridge while other routed providers can receive the same tools directly; tool execution returns through `executeRoutedMcpTool` rather than each provider inventing a separate browser path.

The reusable architectural lesson is therefore not a new Grok runtime. It is a provider-neutral execution policy: prefer structured tool/connector paths, keep safety semantics centralized, and reserve browser/computer interaction for fallback cases.

## Existing Fabushi capabilities

Fabushi already has the necessary primitives on canonical main:

- `AutomationTrigger` supports both schedule and event triggers.
- Listener integrations cover GitHub, Git, Slack, Teams, Linear, Sentry and PagerDuty.
- Connector/MCP tools are exposed through the single Mahayana Host boundary and retain approval requirements.
- Teach/Workflow and Skill surfaces already cover reusable task instructions.
- `host-client.tsx` routes `buildModeTransitionNote(...)` through `modeStatement` on each `chat.send`.

The missing piece was a default run-policy statement that consistently instructs every Mahayana agent turn to use these primitives efficiently.

## Implementation decision

Add one short product-level `EFFICIENT_AGENT_RUN_POLICY` to `fabushi-runtime/agent-utils.ts` and inject it through the existing `buildModeTransitionNote` path. This keeps the policy provider-neutral and automatically reaches ordinary Agent turns without introducing another daemon, tool router or browser controller.

The policy requires:

- event-driven work over polling when a reliable event source exists;
- connected Connector/MCP/API tools over browser/computer UI automation for equivalent actions;
- immediate blocker escalation with the exact human input/action needed;
- narrow event filters and preservation of approvals for destructive/external/publish/send/delete/purchase/production-changing actions.

A lightweight contract check verifies that the policy remains injected into `modeStatement`, event + schedule triggers remain available, and connector discovery remains present.

## Provenance

No reconstructed Grok Bot source code, bundled renderer, installer, or unknown-license resource is copied into Fabushi. The implementation is a clean-room Fabushi-owned policy derived from observable architecture and operating guidance, consistent with the existing GBF source/provenance boundary.
