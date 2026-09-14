# MSR-204 — Hermes-style unified gateway and assistant transcript

Status: `in-progress`

## Source

`projects/mahayana-sovereign-runtime/source/MSR-204-hermes-agent-fusion.md`

Base canonical main at intake: `13188628da46b88db843c9c5b4d59100233e3a21`.
Canonical main advanced during implementation to `429dde3c5b6e7096042606a4f8b1813f044b917e`; that commit is a documentation-only TFI child of the intake base and does not overlap this implementation.
Implementation branch: `feat/msr-204-hermes-gateway-transcript`.
Pinned Hermes audit: `NousResearch/hermes-agent@5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04`.

## Atomic outcome

Introduce the first production-compatible slice of a Mahayana-owned Hermes-style gateway/transcript architecture:

1. Rust owns a versioned event envelope with stable `session_id`, `turn_id`, `seq`, timestamp, replay epoch and typed message/reasoning/tool/approval/clarify/subagent/completion payloads.
2. Existing host/runtime transports can carry the new gateway event additively without removing legacy events during migration.
3. Desktop models one assistant operation as an ordered `AssistantTurn` with parts rather than separate chat + workbench/card state.
4. Legacy `chat.delta`, `operation.started`, `model.routed`, `agent.step`, completion/failure events adapt into that same turn model so the current runtime immediately benefits before every producer switches to the new gateway protocol.
5. The normal Desktop chat path no longer mounts the `MahayanaAgentInlineReport` portal or DOM transcript-semantic bridge that produces the oversized completion card. The workbench must be reduced to an inspector/compatibility surface rather than a second primary transcript.
6. Focused contract/reducer tests prove event ordering, streaming accumulation, tool start→complete replacement, terminal completion and legacy compatibility.

## Acceptance criteria

- [x] Rust product code defines a Mahayana-owned gateway event/frame contract with exact serialized event names such as `message.delta`, `reasoning.delta`, `tool.start`, `tool.complete`, `approval.request`, `clarify.request`, subagent lifecycle and `message.complete`.
- [x] Rust unit tests define expected JSON frame shape, sequence/replay fields, event-name stability and streaming-flush semantics. **Execution result still pending CI.**
- [x] TypeScript product contract represents the same gateway event shape without renderer-owned agent behavior. **Cross-language drift gate remains open.**
- [x] A pure Desktop reducer models one assistant turn and ordered parts across reasoning → text → tool running → tool complete → text → complete. **Product wiring remains open.**
- [x] Current legacy runtime events have an additive reducer path into the same turn model. **The existing Messenger renderer still consumes its older flat projection until the next code slice lands.**
- [x] `desktop/src/main.tsx` no longer mounts `MahayanaAgentInlineReport` or installs its transcript DOM semantic bridge.
- [ ] `MahayanaAgentWorkbench` no longer portals its full `RunCard` into the normal message area; runtime command interception, approvals, resume/interrupt and Bot identity behavior must remain available after the split.
- [ ] `desktop/src/messaging-shell-v2.tsx` consumes the ordered turn/part projection as the primary assistant transcript and no longer renders operation/model/step lifecycle as separate flat messages.
- [ ] Rust runtime/host exposes the new envelope through the actual Mahayana producer path and the same ordered semantics are available to stdio/WebSocket/native consumers.
- [ ] Focused JS/TS and Rust checks pass on the PR exact head.
- [ ] PR passes required repository CI and merges through protected-main governance.
- [ ] Canonical-main packaged Desktop E2E shows a real Mahayana run with thinking/reasoning, streamed assistant text, at least one tool lifecycle and final completion inside one assistant turn; evidence includes screenshots/video/trace/logs tied to exact main SHA.
- [ ] Only after merge + canonical-main readback + required packaged E2E/release evidence may this task become `passed`.

## Implemented in the current branch

- `mahayana-gateway-protocol` Rust workspace crate with a product-owned v1 envelope, JSON-RPC `event` notification shape, event catalog, replay cursor and sequence/gap/stale checks.
- `frontend/apps/web/src/lib/mahayana-host/gateway-events.ts` with the surface-facing v1 contract and runtime guard.
- `desktop/src/mahayana-assistant-turn.ts` with ordered reasoning/text/tool/activity parts and legacy/new-event reducers.
- `desktop/src/mahayana-assistant-turn.css` with compact inline transcript presentation primitives.
- Default Desktop bootstrap no longer mounts `MahayanaAgentInlineReport` or its DOM semantic installer.
- `mahayana-fast-checks.yml` explicitly includes the new Rust gateway protocol crate in the protocol gate.

## Open blockers before merge/acceptance

1. **Workbench split:** `MahayanaAgentWorkbench` still owns both runtime bridge behavior and a portal-rendered `RunCard`. Removing the component wholesale would regress self-hosted bot submission, approvals/resume/interrupt and identity state. It must be split instead of hidden with CSS.
2. **Messenger integration:** the new `AssistantTurn` reducer is intentionally not yet wired into the large legacy `messaging-shell-v2.tsx`; until this is done the old flat `DisplayMessage` remains the primary live transcript.
3. **Producer integration:** the new Rust contract is not yet emitted by the production runtime/host dispatcher. Legacy events continue to be the live source for this branch.
4. **Cross-language drift:** Rust and TypeScript catalogs currently mirror one another but do not yet share a machine-checked canonical event-name fixture.
5. **Verification:** local container networking cannot resolve GitHub, so no local clone/build result is accepted as evidence. GitHub Actions exact-head results are the verification authority for this round.

## Full Hermes fusion follow-on boundary

This atomic task deliberately does **not** claim all Hermes features are already reimplemented. The broader user objective remains open and will be tracked through a source-backed capability matrix covering sessions/resume/interrupt, command dispatch/completion, approvals/clarification/secrets/sudo, MCP, browser/preview/terminal, artifacts/files, subagents/delegation/steer, branch/rewind/compress, model switching, voice/wake, hosted/remote modes, replay/fanout, observability and cross-surface parity. Missing features must be implemented as later MSR atomic tasks in Rust rather than hidden in the renderer.

## Verification plan

- Rust: `cargo fmt --all -- --check`; `cargo test -p mahayana-gateway-protocol --profile ci` plus existing Mahayana fast checks in GitHub Actions.
- Desktop: `npm run build:renderer` (TypeScript + Vite), focused reducer/contract tests once added, then existing Electron tests/E2E where triggered.
- Source-boundary: no Hermes Python runtime/package dependency and no vendor-owned runtime protocol as Mahayana source of truth.
- Product: canonical-main packaged Electron simulated-user E2E, not a static mock/screenshot.

## Risks / rollback

- Protocol migration can regress existing mobile/web consumers. Mitigation: additive gateway contract and legacy adapter first; remove legacy paths only after cross-surface parity.
- Dual rendering can duplicate output. Mitigation: do not enable the ordered-turn renderer until it atomically replaces the old lifecycle projection for the target conversation.
- Hiding the current Workbench panel without splitting its runtime responsibilities would remove approval/resume/interrupt UX. That shortcut is explicitly rejected.
- Upstream architecture evolves. Mitigation: pin the audited Hermes revision in source/evidence and re-audit materially changed areas before claiming full parity.
- License/provenance loss. Mitigation: architecture adaptation by default; preserve MIT notice for any substantial copied/ported code.

## Evidence

Current branch head before opening the PR: `aaa82f80dea1e30633905d55cdc97ed203491e8b`.

Pending: draft PR, exact-head CI runs, remaining product integration, canonical-main merge SHA, packaged E2E bundle and Release traceability.
