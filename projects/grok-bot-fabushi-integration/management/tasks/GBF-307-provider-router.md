# GBF-307 — Mahayana provider Router and readiness

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-307`
- Status: `IN_PROGRESS`
- Started: `2026-08-24 17:57 +08:00`
- Updated: `2026-08-24 20:07 +08:00`
- Completed: —
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified PR head / [#2106](https://github.com/bhrumom/fabushi/pull/2106)

## Objective

Add the provider-neutral Router contract and first production vertical slice identified by the Grok Bot 0.18 audit without introducing a second runtime or bypassing Mahayana policies.

## Source requirements

- `source/2026-08-24-grok-bot-018-reconstructed-fusion.md`
- `GBR-003`, `GBR-004`, `GBR-006`, `GBR-012`, `GBR-014`
- ADR-0007

## In scope

- Persisted `fabushi | codex | claude-code | openrouter` provider contract and `host | local-docker` sandbox contract.
- Read-only native readiness status with no secret values.
- Fabushi default and explicit, authenticated local Codex account routing through the existing in-process Host backend.
- Router settings surface, scoped encrypted Provider credentials, local usage summary, unit/contract/E2E evidence hooks.

## Out of scope

- Copying reconstructed source, renderer bundles, installers or protocol code.

## Dependencies

- GBF-106 released via PR #2105.
- Existing Mahayana FeatureHost, Codex compatibility backend, settings persistence, MCP, approval and usage-event contracts.

## Acceptance criteria and verification

1. Legacy settings deserialize with Fabushi/Host defaults; configured choices round-trip — Rust protocol test in GitHub Actions.
2. Codex selection uses the existing Host generation and local Codex home; Fabushi remains default — Node Host lifecycle tests in GitHub Actions.
3. Readiness detects only local availability/auth state and never returns a secret — native capability tests in GitHub Actions.
4. Claude Messages and OpenRouter Chat Completions normalize into the same Responses/tool/usage contract — Rust provider tests + packaged Playwright checks.
5. Packaged settings journey retains step screenshots, full video, trace and report for exact canonical-main SHA — post-main workflow evidence.
6. PR, protected-main readback, packaged E2E and Release gates pass before completion.

## Open-source survey and decision

- `bhrum/grok-bot-0.18-reconstructed` at pinned commit `a9f633e...` was inspected for observable Router/readiness/settings behavior; its NOTICE/PROVENANCE do not grant upstream source rights, so no code is copied.
- `xai-org/grok-build` (Apache-2.0) remains an architecture reference, not a desktop Router dependency.
- OpenRouter official [Quickstart](https://openrouter.ai/docs/quickstart), [Chat Completions](https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request?explorer=true) and [tool-calling](https://openrouter.ai/docs/guides/features/tool-calling) references were used for the independent adapter.
- Anthropic official [Messages API](https://platform.claude.com/docs/en/api/messages/create), [authentication](https://platform.claude.com/docs/en/manage-claude/authentication) and [model IDs](https://platform.claude.com/docs/en/about-claude/models/model-ids-and-versions) were used for Claude.
- The reference's Cursor provider uses private Cursor account/backend protocols. Fabushi's first-party Mahayana provider is the clean-room functional counterpart; private Cursor auth/protobuf implementation is rejected.
- Reuse the already integrated Mahayana Codex backend and existing FeatureHost DTO/event/MCP/approval paths. Clean-room implement only the new settings and readiness boundary.

## Implementation summary

- Added versioned provider/sandbox settings to Rust and TypeScript contracts with backwards-compatible defaults.
- Added native provider/session/CLI/vault readiness reporting and encrypted OpenRouter presence detection without value disclosure.
- Added Host generation selection for Fabushi/Codex/Claude/OpenRouter and a settings-change restart bridge.
- Added Claude Messages and OpenRouter Chat Completions wire adapters that normalize text, tool calls/results and usage into the native Mahayana Responses contract.
- Provider credentials are scoped to only the selected Host child; unrelated provider secrets are scrubbed from inherited environments.
- Added the Grok-style Router settings panel, provider status, seven-day/lifetime usage, sandbox status, and packaged screenshot checkpoint.

## Evidence

- Index: `evidence/GBF-307/README.md`.
- Lightweight local inspection: CJS syntax and diff checks only; no application build/test locally.
- GitHub PR: #2106. Code-head CI `32725104017`, Host journey `32725104003`, Electron contract `32725103923`, messaging `32725103886`, security `32725103937`, native-mobile `32725103902` and portfolio `32725103915` passed.
- Rust fast run `32725103949` exposed a no-default-features `Duration` import gate; the unified head removes the incorrect feature guard and awaits the final rerun. Main/package/Release remain pending.

## Risks / blockers

- A local auth file proves account presence, not that a network request will succeed; runtime errors must remain visible and recoverable.
- Provider switch restarts the Host generation. Existing provider-neutral durable conversations remain intact, but routed continuity evidence belongs to GBF-308.
- The persisted compatibility ID remains `claude-code`, but inference uses an explicit Claude API key; a local Claude Code subscription/session is diagnostic only and is never misrepresented as an API credential.

## Next action

Complete the final unified-head rerun, merge through protected `main`, then collect exact-SHA packaged Windows/macOS/Linux E2E/visual evidence and Release linkage.
