# MSR-203 — Native web research

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-203
- **Status:** in-progress
- **Started:** 2026-08-28
- **Updated:** 2026-08-28
- **Completed:** null

## Objective
Give the Mahayana native Agent loop a first-class, provider-neutral web research capability comparable to Codex web search, backed initially by TinyFish Search + Fetch rather than an external browser/MCP.

## User source requirement
The user explicitly corrected that `.agent/skills/bb-browser` is an unused external MCP/browser dependency and must not be treated as a built-in Fabushi Bot capability. The requested behavior is for Bots to autonomously search and read the live web during multi-step work, like Codex, using the free approach referenced from `https://monid.ai/blog/tinyfish` when Fabushi lacks an equivalent built-in search backend.

## Open-source / upstream research
- OpenAI Codex current source: web search is a first-class runtime tool (`WebSearch` / `web` namespace) participating in the Agent tool loop; it is not implemented as a browser MCP.
- TinyFish official Search API: `GET https://api.search.tinyfish.ai?query=...` with `X-API-Key`.
- TinyFish official Fetch API: `POST https://api.fetch.tinyfish.ai` with `X-API-Key`; supports batches of URLs and clean text/markdown extraction.
- TinyFish Cookbook is MIT licensed. We reuse the documented HTTP contract and design pattern, not copied implementation code.
- Monid is not selected as the runtime dependency: its current CLI/API requires Monid authentication and adds a marketplace/run indirection that is unnecessary for web research. Mahayana will keep a provider-neutral tool contract and use TinyFish directly as the first backend.

## In scope
- Native Mahayana `web_search` and `web_fetch` tools in the production Agent loop.
- `Capability::WebSearch` advertisement only when a web provider is configured.
- TinyFish provider with explicit secret configuration and overridable endpoints for tests.
- Network-policy enforcement, existing tool authorization/loop/hooks/event flow, bounded outputs and sanitized provider failures.
- Unit/conformance tests without requiring a live TinyFish key.
- Project capability matrix and operator configuration documentation.

## Out of scope
- Treating `bb-browser` as built-in search.
- Browser/computer-use interaction for login-only or click-heavy sites.
- Shipping a TinyFish API key in client source or binaries.
- Replacing TinyFish with OpenAI paid Web Search.

## Acceptance criteria
1. Mahayana exposes `web_search` and `web_fetch` to the model only when a web provider is configured.
2. Both tools execute inside the canonical native tool path: loop protection, hooks, tool events, permission/policy evaluation and result feedback to the model.
3. `allow_network=false` blocks web tools before any provider request.
4. Native engine advertises `Capability::WebSearch` only when configured and can satisfy a required WebSearch capability in that state.
5. TinyFish API key is injected at runtime and is never included in tool arguments, results, events or error strings.
6. Search results and fetched page content are structured and bounded; fetch accepts at most 10 public HTTP(S) URLs per request.
7. Tests prove successful search/fetch mapping, missing configuration behavior, network-policy denial, URL validation and key redaction using local/mock endpoints only.
8. Codex/TinyFish provenance and the provider decision are recorded in the project docs.
9. PR passes required CI, merges through protected `main`, and canonical-main delivery evidence is recorded before the task is marked complete.

## Branch / commit / PR
Branch: `feat/msr-203-native-web-research`
Commit: in progress
PR: pending

## Current evidence
- Canonical `main` at task start: `c247786ab98c94c414d976e08e13626db352b07f`.
- `mahayana-kernel::Capability` already contains `WebSearch`, but `mahayana-native-engine` does not advertise it or define/execute web tools.
- The current native tool list contains workspace, memory, workflow, subagent, process and git tools only.

## Blockers / risks
- TinyFish Search/Fetch are free but require a free TinyFish API key. The implementation must be complete without embedding a credential; production activation requires secret provisioning.
- Mobile/Web must not embed a shared service credential in untrusted client code; secret routing must remain on a trusted runtime/server boundary.

## Next action
Implement the provider-neutral web research module, bind it to the native tool bus, add tests, then drive the PR through CI/main and post-main evidence.