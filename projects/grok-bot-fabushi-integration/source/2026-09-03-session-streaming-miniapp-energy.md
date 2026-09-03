# 2026-09-03 — Session / streaming / generated Mini App / desktop energy parity

## User requirement

The user reported five observable product failures on the current Fabushi release and asked for an actual implementation, not another analysis-only round:

1. Mobile signs the user out after the app process is terminated and reopened.
2. Desktop does not expose an obvious logout action in the normal profile/navigation surface.
3. Assistant replies still appear as whole blocks instead of true provider-token streaming.
4. Desktop consumes excessive power while idle/backgrounded.
5. Agent-created runnable Mini Apps are surfaced as code/text rather than an interactive artifact that can be opened directly.

The user explicitly pointed to `bhrum/grok-bot-0.18-reconstructed` as the observable interaction baseline and asked why Fabushi cannot provide the same event-driven conversation form and usable final artifacts.

## Open-source-first / reference inspection

- `bhrum/grok-bot-0.18-reconstructed` pinned project input remains the primary parity reference. Its production renderer consumes coordinator event subscriptions and structured transcript components rather than polling transcript text as a completed blob.
- Fabushi already has a single Mahayana runtime, `chat.delta`, structured `TranscriptCard`, an isolated `fabushi-miniapp://` desktop document scheme, and Mini App runtime/opening boundaries. This round therefore extends those existing boundaries instead of importing a second Grok runtime.
- For provider streaming, use each provider's native SSE contract (OpenAI Responses, OpenAI-compatible Chat Completions, Anthropic Messages) and preserve the existing provider-neutral `ModelEvent::OutputTextDelta` boundary.
- For generated Mini Apps, reuse the existing isolated Mini App document surface and CSP rather than opening arbitrary external HTML or adding a parallel WebView runtime.

## Engineering ownership

This cross-cutting parity round is tracked under `GBF-805` as the observable closure task. Account-session durability is linked to the account-access-control project, and idle-energy evidence remains linked to `MSR-106`.

## Acceptance additions for this round

- Provider HTTP requests enable real streaming; at least two deltas are observable before terminal completion in deterministic parser/transport tests.
- Streaming preserves final normalized payload, tool calls, usage accounting, cancellation semantics, and existing `chat.delta` event shape.
- Desktop profile/avatar navigation exposes a visible `退出登录` action in addition to Settings > General.
- Mobile production auth state survives a full process recreation using OS-protected durable key material; logout clears the durable account session.
- A structured Mini App transcript artifact renders as a product card with an `打开小程序` action and opens through Fabushi's isolated Mini App surface instead of a JSON/code `<pre>`.
- Full HTML Mini App deliverables emitted by the agent can be promoted into the structured artifact path without treating ordinary code examples as executable artifacts.
- Background runtime receive keeps the proven bounded 500 ms serial-Host long poll, wakes immediately on real events, and yields between receives; energy reduction must come from eliminating busy loops/frame fan-out rather than blocking auth/settings IPC for tens of seconds.
- Required implementation, CI, packaged E2E, visual evidence, protected-main merge, and post-main Release gates remain mandatory before this task is marked complete.
