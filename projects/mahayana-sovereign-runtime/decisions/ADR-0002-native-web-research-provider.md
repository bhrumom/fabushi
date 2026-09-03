# ADR-0002 — Native web research is a Mahayana capability; TinyFish is the first provider

- Status: accepted for MSR-203 implementation; production activation pending credential provisioning and protected-main delivery
- Date: 2026-08-28
- Project: FAB-P0005 / MSR

## Context
The Bot needs to autonomously search the live internet and read source pages while it is already executing a multi-step task. `.agent/skills/bb-browser` is an external browser/MCP component and is not part of the native Mahayana Agent capability set.

OpenAI Codex was re-audited at current main `41d3dc56a0e1de47e30a9585c1b49253c082f8f7`. The relevant architectural lesson is to make web research a first-class Agent runtime tool participating in the same model/tool loop rather than requiring a separate browser MCP. OpenAI's hosted Web Search API is a paid service and is therefore not selected as the default provider for this requirement.

The user-provided TinyFish/Monid source led to the official TinyFish Search and Fetch APIs. TinyFish's cookbook documents direct `X-API-Key` Search/Fetch calls and is MIT licensed. Monid adds marketplace/auth/run indirection that is unnecessary for Mahayana's stable product contract.

## Decision
1. Mahayana owns the stable tools `web_search` and `web_fetch`; provider names are not exposed as model tool names.
2. Both tools run through the existing native Agent loop: model tool selection, loop guard, Hooks, permission/policy evaluation, tool start/completion events and function-call output feedback.
3. `Capability::WebSearch` is advertised only when a provider is configured. `allow_network=false` denies the capability before a provider request.
4. TinyFish Search/Fetch are the first provider. `TINYFISH_API_KEY` is runtime-only; no key is embedded in source, client binaries, tool arguments, events, results or provider errors.
5. Fetch accepts only bounded public HTTP(S) targets and bounded extracted content. Browser/computer-use remains a separate fallback capability for interactive/login-heavy pages.
6. Provider configuration remains replaceable so a future free/self-hosted search backend can be added without changing Bot-facing tool semantics.

## Consequences
- Bots can autonomously decide to search and then fetch sources during a normal Mahayana task once the trusted runtime has a TinyFish key.
- Desktop/mobile/web shells do not need to understand TinyFish-specific request formats.
- A missing key fails closed by not advertising `WebSearch`; production operations must provision the key through a trusted secret boundary rather than packaging it in clients.
- Live-provider availability and quotas are operational dependencies, while unit/conformance verification remains deterministic through mocks.

## Provenance
- OpenAI Codex current-main architecture audit, 2026-08-28.
- TinyFish official cookbook/API examples (`tinyfish-io/tinyfish-cookbook`), MIT license.
- User source: `https://monid.ai/blog/tinyfish`.
