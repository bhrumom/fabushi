# MSR-502 source requirement — Mahayana CLI control-plane parity

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Captured:** 2026-08-25
- **Origin:** Direct user request in the Fabushi project

## Original requirement

Fuse the strongest architecture and behavior from `xai-org/grok-build` and `openai/codex` into the Fabushi-owned Mahayana product rather than exposing Mahayana as a rebranded upstream. Integrate the existing Telegram/Grok Bot product work into Mahayana so the CLI can perform the same control-plane operations as desktop: create/select/chat with bots, install Mini Apps, create Mini Apps, publish Mini Apps, and act as the canonical product engine wrapped by desktop/mobile clients. Merge verified work into `main`, run complete CLI acceptance tests, and only publish desktop/mobile releases after canonical-main package and E2E gates pass.

## Existing baseline verified before this task

- Mahayana already owns the public Host protocol, runtime identity, model/tool policy plane, platform adapters, and vendor-isolation checks.
- Grok Build orchestration concepts and Codex local-agent compatibility have already been mapped into the Mahayana convergence project; direct vendor product types remain adapter-only.
- The shared Host protocol already supports bot create/update/clone/delete/list/hide operations.
- The Telegram-style Mini App marketplace and BotFather backend already expose browse/search/add/remove/generate/draft/submit/review/yank and per-Mini-App bot endpoints.
- The remaining gap is primarily CLI exposure and canonical Mahayana identity, not a missing second runtime.

## Open-source-first review

| Candidate | License | Reused/adapted | Explicitly not copied |
|---|---|---|---|
| `xai-org/grok-build` | Apache-2.0 | resumable multi-step orchestration, queue/steer semantics, subagents, workflow/tool UX, cancellation/resilience patterns | vendor branding, product-specific public contracts, direct source-tree identity |
| `openai/codex` | Apache-2.0 | mature local coding loop, approvals/sandboxing, MCP/skills/plugin compatibility, session recovery and headless operation | OpenAI/Codex public product identity, mandatory vendor authentication, vendor-owned CLI namespace |
| Fabushi Telegram/Grok Bot integration | repository-owned | marketplace/BotFather lifecycle, bot-centric messaging UX, Mini App bot endpoints, shared desktop/mobile behavior | Telegram API dependency as the Mahayana core or a separate duplicated state store |

## Atomic acceptance for MSR-502

1. `mahayana bot` exposes create, update, clone, delete, list, hide/show, and bot chat/select behavior through the existing Host protocol.
2. `mahayana miniapp` exposes registry, search, added/list, install, open, chat, BotFather generation, manifest-backed draft creation, and submit-for-review publication.
3. Install/open reuse the shared Feature Host; marketplace publication uses the first-party authenticated Mahayana product client.
4. Newly emitted bot conversation IDs use `mahayana-ai:agent:*`; persisted legacy `codex:agent:*` values remain readable but are not newly generated.
5. Parser/contract/state tests cover new commands, invalid input, auth-sensitive publication paths, and canonical IDs.
6. The PR passes required Rust/CLI/project-governance CI, merges into protected `main`, and is read back from canonical `main`.
7. Product release remains open until exact-main desktop/mobile package + simulated-user E2E + release evidence exists; no release-complete claim is permitted earlier.
