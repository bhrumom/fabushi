# GBF-307 — Mahayana provider Router and readiness

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-307`
- Status: `RELEASED`
- Started: `2026-08-24 17:57 +08:00`
- Updated: `2026-08-24 21:56 +08:00`
- Completed: `2026-08-24 21:56 +08:00`
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified head `4d8d3a6a...` / [#2106](https://github.com/bhrumom/fabushi/pull/2106) / main `f81588d3...`

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
- GitHub PR: #2106 retained one unified commit; canonical seven-gate run `32731980249` passed against head `4d8d3a6a...`, including Electron `32731991098`, native mobile `32731993782`, CI `32731988653`, Mahayana, messaging, security and computer-control gates.
- Protected merge queue accepted main SHA `f81588d33c1f10610ed0d0e4b147ae239b72b3a3` after merge-group CI `32733468063`.
- Exact-main Electron run `32733627050` built and launched Windows/macOS/Linux packages and retained passing Playwright screenshots/video/trace/report; native mobile run `32733627056` passed Android/iOS simulated-user journeys.
- Post-main delivery `32734915241` published [desktop-1.0.867](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.0.867) targeting the exact main SHA with Windows installer, blockmap and `latest.yml` updater metadata.

## Risks / blockers

- A local auth file proves account presence, not that a network request will succeed; runtime errors must remain visible and recoverable.
- Provider switch restarts the Host generation. Existing provider-neutral durable conversations remain intact, but routed continuity evidence belongs to GBF-308.
- The persisted compatibility ID remains `claude-code`, but inference uses an explicit Claude API key; a local Claude Code subscription/session is diagnostic only and is never misrepresented as an API credential.

## Next action

None for GBF-307. Subsequent full-reference parity gaps remain tracked by GBF-805.
