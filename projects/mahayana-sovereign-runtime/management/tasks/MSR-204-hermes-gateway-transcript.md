# MSR-204 — Hermes-style unified gateway and assistant transcript

Status: `in-progress`

## Source

`projects/mahayana-sovereign-runtime/source/MSR-204-hermes-agent-fusion.md`

Base canonical main at intake: `13188628da46b88db843c9c5b4d59100233e3a21`.
Canonical main advanced during implementation to `429dde3c5b6e7096042606a4f8b1813f044b917e`; that observed change was documentation-only TFI work and did not overlap this implementation.
Implementation branch: `feat/msr-204-hermes-gateway-transcript`.
Draft PR: `#2620`.
Pinned Hermes audit: `NousResearch/hermes-agent@5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04`.
Capability matrix: `projects/mahayana-sovereign-runtime/management/MSR-204-HERMES-PARITY.md`.

## Atomic outcome

Introduce the first production-compatible slice of a Mahayana-owned Hermes-style gateway/transcript architecture:

1. Rust defines a versioned event envelope with stable `session_id`, `turn_id`, `seq`, timestamp, replay epoch and typed message/reasoning/tool/approval/clarify/subagent/completion payloads.
2. Existing host/runtime transports can adopt the new event additively without removing legacy events during migration.
3. Desktop models one assistant operation as an ordered `AssistantTurn` with parts rather than separate chat + workbench/card state.
4. Legacy `chat.delta`, `operation.started`, `model.routed`, `agent.step`, completion/failure events adapt into that same turn model before every producer switches to the new protocol.
5. Routine successful runs no longer show the oversized Workbench completion card in normal chat; approval/failure/interruption controls remain available during migration.
6. The final cutover replaces Messenger's flat lifecycle rows with the ordered turn renderer and makes the Rust session/conversation store authoritative for replay/recovery.

## Acceptance criteria

- [x] Rust code defines a Mahayana-owned gateway event/frame contract with exact serialized event names including `message.delta`, `reasoning.delta`, `tool.start`, `tool.complete`, `approval.request`, `clarify.request`, subagent lifecycle and `message.complete`.
- [x] Rust unit tests define expected JSON frame shape, sequence/replay fields, event-name stability and streaming-flush semantics. **Execution on the final exact head is still required.**
- [x] TypeScript product contract represents the same gateway event shape without renderer-owned agent behavior.
- [x] Rust/TypeScript event catalogs have a machine-checked drift gate; an earlier exact-head Mahayana run reached and passed this gate before failing later on rustfmt.
- [x] A pure Desktop reducer models one assistant turn and ordered parts across reasoning → text → tool running → tool complete → text → complete. **Primary Messenger wiring remains open.**
- [x] Current legacy runtime events have an additive reducer path into the same turn model.
- [x] A presentation-only `MahayanaAssistantTurnView` renders ordered reasoning/text/tool/activity parts without owning tools, approvals, persistence or sequencing.
- [x] `desktop/src/main.tsx` no longer mounts `MahayanaAgentInlineReport` or installs its transcript DOM semantic bridge.
- [x] Routine Workbench `queued/running/completed` RunCards are removed from the visible chat path while `waiting-for-approval`, `failed`, and `interrupted` Inspector states remain available.
- [ ] Structurally split `MahayanaAgentWorkbench` runtime/identity bridge responsibilities from its remaining interactive Inspector rendering; remove the normal timeline portal dependency once Messenger cutover is complete.
- [ ] `desktop/src/messaging-shell-v2.tsx` consumes the ordered turn/part projection as the primary assistant transcript and no longer renders operation/model/step lifecycle as separate flat messages.
- [ ] Rust runtime/host emits the new envelope through the actual Mahayana producer path and exposes the same ordered semantics to stdio/WebSocket/native consumers.
- [ ] Final exact-head Rust/TypeScript/Desktop checks all pass after the last code/project-record commit.
- [ ] PR passes required repository CI and merges through protected-main governance.
- [ ] Canonical-main packaged Desktop E2E shows a real Mahayana run with thinking/reasoning, streamed assistant text, at least one tool lifecycle and final completion inside one assistant turn; evidence includes screenshots/video/trace/logs tied to exact main SHA.
- [ ] Every in-scope row in `MSR-204-HERMES-PARITY.md` is either proven `present` or explicitly excluded by a product decision before anyone claims full Hermes fusion/parity.
- [ ] Only after protected merge + canonical-main readback + packaged E2E/release evidence may this task become `passed`.

## Implemented in the current branch

- `mahayana-gateway-protocol` Rust crate with a product-owned v1 envelope, JSON-RPC `event` notification shape, event catalog, replay cursor and sequence/gap/stale checks.
- The protocol crate is temporarily isolated from the root Cargo workspace so the foundation can be independently formatted/tested without hand-editing the repository's generated root `Cargo.lock`. It must join the actual host/runtime dependency graph as part of producer integration using a normal Cargo-generated lock update.
- `frontend/apps/web/src/lib/mahayana-host/gateway-events.ts` with the surface-facing v1 contract and runtime guard.
- `.github/scripts/check-mahayana-gateway-event-drift.py` enforcing exact ordered event-name parity between Rust and TypeScript.
- `desktop/src/mahayana-assistant-turn.ts` with ordered reasoning/text/tool/activity parts and legacy/new-event reducers.
- `desktop/src/mahayana-assistant-turn-view.tsx` with a presentation-only ordered turn renderer.
- `desktop/src/mahayana-assistant-turn.css` with compact inline transcript presentation primitives and migration CSS that removes routine Workbench completion cards while retaining approval/recovery states.
- Default Desktop bootstrap no longer mounts `MahayanaAgentInlineReport` or its DOM semantic installer.
- `mahayana-fast-checks.yml` runs the isolated gateway crate's rustfmt/unit tests and the Rust/TypeScript drift gate in addition to the existing root-workspace checks.
- `MSR-204-HERMES-PARITY.md` turns the broad "all Hermes features" request into an evidence-based implement/audit/missing matrix and staged closure order.

## Verification observed so far

Historical failures are retained because they are useful evidence and are **not** counted as passing the current head:

1. An early Mahayana fast-check run passed source ownership and the new Rust/TypeScript 14-event drift gate, then failed `cargo fmt --all -- --check`. The Rust source was reformatted in the next commit.
2. A later control-plane check failed because adding a new root workspace member required a `Cargo.lock` update under `--locked`. Rather than hand-edit generated lock state, the gateway foundation was temporarily isolated and the root workspace change was reverted.
3. On code head `54c234b8a29835fd2fdf7e035745c9989783e311`, the Electron quality gate had already passed canonical architecture/UI contracts, Electron main-process tests, and `npx tsc --noEmit`; CI, Host fast E2E, Vendor Isolation, project governance and explicit-automerge checks were also green or progressing. Subsequent documentation commits invalidate that head as the final verification target, so checks must be read again on the final exact head.

Local container networking cannot resolve GitHub; no local clone/build result is represented as verification. GitHub Actions exact-head results are the accepted verification source for this round.

## Open blockers before merge / acceptance

1. **Messenger cutover:** `messaging-shell-v2.tsx` still uses the flat `DisplayMessage` projection (`thinking`, `action`, `message`). The new reducer/view is compiled but not yet the primary live renderer.
2. **Workbench structural split:** routine cards are visually removed, but Workbench still owns command interception, approval/resume/interrupt, identity replacement and a portal for exceptional interactive states. Those behavior responsibilities must be separated before deleting the portal code.
3. **Producer integration:** the new Rust contract is not yet emitted by the production host/runtime dispatcher; live Desktop behavior continues to originate from legacy runtime events.
4. **Rust workspace integration:** the isolated protocol crate must be consumed by the real host/runtime and brought into the canonical workspace/lockfile through normal Cargo generation, not a manual lock edit.
5. **Full Hermes scope:** many rows in the capability matrix remain `audit`, `partial`, or `missing / unverified`; full parity is explicitly not claimed.
6. **Canonical packaged evidence:** no protected-main merge or fresh packaged macOS/Windows/Linux proof exists for MSR-204 yet.

## Verification plan

- Gateway Rust foundation: `cargo fmt --manifest-path mahayana-gateway-protocol/Cargo.toml -- --check` and `cargo test --manifest-path mahayana-gateway-protocol/Cargo.toml` in GitHub Actions.
- Existing Mahayana root: unchanged `cargo fmt --all -- --check` plus the established fast-check package set.
- Desktop: dependency-free architecture/UI contracts, main-process tests, `npx tsc --noEmit`, renderer build, real Rust Host pre-package user journey.
- Source boundary: no Hermes Python runtime/package dependency and no vendor-owned runtime protocol as Mahayana source of truth.
- Product completion: protected-main packaged Electron simulated-user E2E, not a static mock/screenshot.

## Risks / rollback

- Protocol migration can regress existing mobile/web consumers. Mitigation: additive gateway contract and legacy adapter first; remove legacy events only after cross-surface parity.
- Dual rendering can duplicate output. Mitigation: do not enable the ordered-turn renderer until it atomically replaces the old lifecycle projection for the target conversation.
- Removing Workbench wholesale would regress self-hosted submit, approval/resume/interrupt and identity state. Migration CSS therefore suppresses only routine cards while exceptional interactive states remain reachable.
- Upstream architecture evolves. Mitigation: pin the audited Hermes revision and re-audit materially changed upstream areas before claiming parity.
- License/provenance loss. Mitigation: architecture adaptation by default; preserve the upstream MIT notice for any substantial copied/ported implementation.

## Evidence

- Draft PR: `#2620`.
- Current capability matrix: `projects/mahayana-sovereign-runtime/management/MSR-204-HERMES-PARITY.md`.
- Final exact-head CI, canonical-main merge SHA, packaged E2E bundle and Release traceability: pending.
