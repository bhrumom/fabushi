# MSR-204 — Hermes-style unified gateway and assistant transcript

Status: `in-progress`

## Source

`projects/mahayana-sovereign-runtime/source/MSR-204-hermes-agent-fusion.md`

Base canonical main at intake: `13188628da46b88db843c9c5b4d59100233e3a21`.
Implementation branch: `feat/msr-204-hermes-gateway-transcript`.
Pinned Hermes audit: `NousResearch/hermes-agent@5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04`.

## Atomic outcome

Introduce the first production-compatible slice of a Mahayana-owned Hermes-style gateway/transcript architecture:

1. Rust owns a versioned event envelope with stable `session_id`, `turn_id`, `seq`, timestamp, replay epoch and typed message/reasoning/tool/approval/clarify/subagent/completion payloads.
2. Existing host protocol can carry the new gateway event without removing legacy events during migration.
3. Desktop models one assistant operation as an ordered `AssistantTurn` with parts rather than separate chat + workbench/card state.
4. Legacy `chat.delta`, `operation.started`, `model.routed`, `agent.step`, completion/failure events adapt into that same turn model so the current runtime immediately benefits before every producer switches to the new gateway protocol.
5. The normal Desktop chat path no longer mounts the `MahayanaAgentInlineReport` portal or DOM transcript-semantic bridge that produces the oversized completion card. The workbench may remain as an inspector/compatibility surface, not the primary transcript.
6. Focused contract/reducer tests prove event ordering, streaming accumulation, tool start→complete replacement, terminal completion and legacy compatibility.

## Acceptance criteria

- [ ] Rust `mahayana-host-protocol` exposes a gateway event/frame contract with exact serialized event names such as `message.delta`, `reasoning.delta`, `tool.start`, `tool.complete`, `approval.request`, `clarify.request`, subagent lifecycle and `message.complete`.
- [ ] Rust unit tests verify JSON frame shape, sequence/replay fields and event-name stability.
- [ ] TypeScript product contract represents the same gateway event shape without renderer-owned agent behavior.
- [ ] Desktop reducer preserves one assistant turn per operation/turn and ordered parts across reasoning → text → tool running → tool complete → text → complete.
- [ ] Current legacy runtime events feed the same reducer, with lifecycle/model metadata rendered as compact transcript activity rather than a second completion report.
- [ ] `desktop/src/main.tsx` does not mount the legacy inline-report portal/transcript DOM bridge in the default chat path.
- [ ] Focused JS/TS and Rust checks pass on the PR exact head.
- [ ] PR passes required repository CI and merges through protected-main governance.
- [ ] Canonical-main packaged Desktop E2E shows a real Mahayana run with thinking/reasoning, streamed assistant text, at least one tool lifecycle and final completion inside one assistant turn; evidence includes screenshots/video/trace/logs tied to exact main SHA.
- [ ] Only after merge + canonical-main readback + required packaged E2E/release evidence may this task become `passed`.

## Full Hermes fusion follow-on boundary

This atomic task deliberately does **not** claim all Hermes features are already reimplemented. The broader user objective remains open and will be tracked through a source-backed capability matrix covering sessions/resume/interrupt, command dispatch/completion, approvals/clarification/secrets/sudo, MCP, browser/preview/terminal, artifacts/files, subagents/delegation/steer, branch/rewind/compress, model switching, voice/wake, hosted/remote modes, replay/fanout, observability and cross-surface parity. Missing features must be implemented as later MSR atomic tasks in Rust rather than hidden in the renderer.

## Verification plan

- Rust: `cargo fmt --all -- --check`; focused `cargo test -p mahayana-host-protocol` through GitHub Actions/fast checks.
- Desktop: existing package test runner plus new pure reducer/contract tests; TypeScript build/typecheck where configured.
- Source-boundary: no Hermes Python runtime/package dependency and no vendor-owned runtime protocol as Mahayana source of truth.
- Product: canonical-main packaged Electron simulated-user E2E, not a static mock/screenshot.

## Risks / rollback

- Protocol migration can regress existing mobile/web consumers. Mitigation: additive host event and legacy adapter first; remove legacy paths only after cross-surface parity.
- Dual rendering can duplicate output. Mitigation: default transcript consumes ordered turn state and stops mounting the inline-report bridge; workbench stays inspector-only.
- Upstream architecture evolves. Mitigation: pin the audited Hermes revision in source/evidence and re-audit materially changed areas before claiming full parity.
- License/provenance loss. Mitigation: architecture adaptation by default; preserve MIT notice for any substantial copied/ported code.

## Evidence

Pending: implementation commit(s), PR, CI runs, canonical-main SHA, packaged E2E bundle and Release traceability.
