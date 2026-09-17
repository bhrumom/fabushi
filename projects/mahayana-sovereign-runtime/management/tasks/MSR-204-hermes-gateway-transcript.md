# MSR-204 — Hermes-style unified gateway and assistant transcript

Status: `in-progress`

## Source

`projects/mahayana-sovereign-runtime/source/MSR-204-hermes-agent-fusion.md`

Base canonical main at intake: `13188628da46b88db843c9c5b4d59100233e3a21`.
Canonical main observed during this execution: `429dde3c5b6e7096042606a4f8b1813f044b917e`.
Implementation branch: `feat/msr-204-hermes-gateway-transcript`.
Draft PR: `#2620`.
Original pinned Hermes audit: `NousResearch/hermes-agent@5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04`.
Latest Hermes `main` observed/re-read in this execution: `NousResearch/hermes-agent@4d55ca91656ac5f83e1506679b7f81e0238e5e16`.
Capability matrix: `projects/mahayana-sovereign-runtime/management/MSR-204-HERMES-PARITY.md`.

The original pin remains the provenance baseline for the existing matrix. The latest upstream read is materially newer and must be treated as an explicit delta audit before anyone claims current Hermes parity. In particular, current Hermes uses one gateway for TUI/Desktop/Web and now models approval/clarify/sudo/secret/vault/connection/desktop-bridge interactions as server→client JSON-RPC requests whose open state can be restored on session resume/replay.

## Atomic outcome

Introduce the first production-compatible slice of a Mahayana-owned Hermes-style gateway/transcript architecture:

1. Rust owns a versioned ordered gateway envelope with stable session/turn identity, monotonic sequence, timestamp, replay epoch and typed message/reasoning/tool/approval/clarify/subagent/completion payloads.
2. Mahayana exposes a transport-neutral Rust gateway plus a CLI stdio JSON-RPC dispatcher instead of embedding Hermes' Python runtime.
3. Desktop models one assistant operation as an ordered `AssistantTurn` with parts rather than separate chat + Workbench completion-card state.
4. Legacy runtime events and self-hosted Bot invocation are adapted into that same turn during migration.
5. Routine successful runs no longer surface the oversized Workbench completion card in normal chat; exceptional approval/failure/interruption Inspector behavior remains during migration.
6. Final parity still requires Rust-owned session/replay authority, the same dispatcher semantics over stdio/WebSocket/native clients, server→client request correlation, remaining Hermes capabilities, cross-surface proof and self-contained packaged releases.


## 2026-09-17 governed resynchronization

- Canonical main re-read before this sync: `55a7e167b728ebc6aa43e1523cc2de520f622e9b`, after #2297/#2299/#2316 landed.
- Previous remote PR head: `5183d12b25fd0a90b0cdd2de86fd0df0ee2520de`.
- The current sync keeps `main`'s finished-operation/interruption recovery and ordinary-message/generated-Mini-App behavior while retaining the canonical `AssistantTurn` projection for Mahayana replies.
- The retired automatic `mahayana-fast-checks.yml` workflow remains deleted in accordance with current repository governance; no deleted automatic E2E gate is revived.
- No local build or product test was run. Fresh GitHub Actions checks must bind to the pushed head.
- This synchronization does **not** close the pre-existing MSR-204 blockers: canonical restart durability, shared Host dispatcher/peer registry, non-approval server-request families, and the in-scope latest-Hermes OpenRPC method matrix remain implementation work until separately evidenced.
- The exact resulting head is read back from GitHub metadata after push rather than self-embedded into the same commit.


## 2026-09-17 post-merge acceptance repair — durability round

- Protected merge queue placed PR #2620 into canonical `main@52cee303e6e8c599af0a5247b412b068bfce20f1` while this task record still had explicit acceptance blockers. Merge is therefore source integration evidence, not task completion evidence.
- This follow-up round restores the previously reviewed Rust durability wrappers for gateway replay and peer open-request state, activates them as the crate entry points, and changes the CLI gateway to use the persistent peer registry. Both wrappers share the same private, atomic `gateway-state-v1.json` document and preserve each other's subtree.
- No local build/test is accepted or represented here. Exact-head GitHub Actions must prove compilation, durability restart tests, gateway/peer tests and affected product gates before the durability acceptance item may be checked.
- Remaining MSR-204 acceptance work after this round still includes the shared production Host dispatcher/transport path, non-approval server-request producers/resolution semantics, Workbench/Inspector responsibility split, exact-main packaged proof, and explicit ownership decisions for broader Hermes parity rows.

## Acceptance criteria

- [x] Rust code defines a Mahayana-owned gateway event/frame contract with exact serialized event names including `message.delta`, `reasoning.delta`, `tool.start`, `tool.complete`, `approval.request`, `clarify.request`, subagent lifecycle and `message.complete`.
- [x] Rust unit tests define JSON frame shape, sequence/replay fields, event-name stability and streaming-flush semantics.
- [x] TypeScript product contract represents the same gateway event shape without renderer-owned agent execution behavior.
- [x] Rust/TypeScript event catalogs have a machine-checked drift gate.
- [x] A pure Desktop reducer models one assistant turn and ordered parts across reasoning → text → tool running → tool complete → continued text → completion.
- [x] Current legacy runtime events have an additive reducer path into the same turn model.
- [x] A presentation-only `MahayanaAssistantTurnView` renders ordered reasoning/text/tool/activity parts without owning tools, approvals, persistence or sequencing.
- [x] `desktop/src/main.tsx` no longer mounts `MahayanaAgentInlineReport` or installs its transcript DOM semantic bridge.
- [x] Routine Workbench `queued/running/completed` RunCards are removed from the visible chat path while `waiting-for-approval`, `failed`, and `interrupted` Inspector states remain available.
- [x] `desktop/src/messaging-shell-v2.tsx` uses the ordered `AssistantTurn` projection for the active Mahayana operation instead of emitting operation/model/step lifecycle as separate normal chat rows.
- [x] A final legacy `chat.message` seals the live assistant turn as `completed`, rather than leaving a visually complete response in `running` state.
- [x] The self-hosted Bot `chat.send` command bridge dispatch/accepted lifecycle is observed by Messenger, claims the operation, and feeds the same ordered assistant turn instead of creating a second task-card surface.
- [x] `mahayana-gateway-protocol` and `mahayana-gateway` are in the canonical Rust workspace and `Cargo.lock` was generated by Cargo; no manual lock editing is represented as evidence.
- [x] A Rust `mahayana-gateway` CLI binary dispatches the initial JSON-RPC method set over stdio and the Rust gateway projection/replay/protocol tests pass in GitHub Actions.
- [ ] Structurally split `MahayanaAgentWorkbench` runtime/identity/approval/recovery bridge responsibilities from its remaining exceptional-state Inspector rendering and remove the obsolete normal timeline portal dependency.
- [ ] Make the production Rust runtime/host the canonical ordered producer and expose the same session/replay/request semantics to stdio, WebSocket and native/embed consumers.
- [ ] Add Hermes-current server→client JSON-RPC request/response correlation and reconnect restoration for approval/clarify/sudo/secret/vault/connection/desktop-bridge interactions; events alone are not parity.
- [ ] Move canonical conversation/turn/part/replay authority into Rust so renderer restart/app restart does not rely on local UI journals.
- [ ] Final exact-head Rust/TypeScript/Desktop checks all pass after the last code/project-record commit.
- [ ] PR passes required repository CI and merges through protected-main governance.
- [ ] Canonical-main packaged Desktop E2E shows a real Mahayana run with thinking/reasoning, streamed assistant text, at least one tool lifecycle and final completion inside one assistant turn; evidence includes screenshots/video/trace/logs tied to exact main SHA.
- [ ] Every in-scope row in `MSR-204-HERMES-PARITY.md` is either proven `present` against the then-current audited Hermes revision or explicitly excluded by a product decision before anyone claims full Hermes fusion/parity.
- [ ] Only after protected merge + canonical-main readback + packaged E2E/release evidence may this task become `passed`.

## Implemented in the current branch

- `mahayana-gateway-protocol`: product-owned v1 ordered envelope, JSON-RPC event notification shape, event catalog, replay cursor and stale/gap/sequence checks.
- `mahayana-gateway`: Rust runtime-event projection into ordered gateway events, per-session sequence/replay buffering and session/replay dispatcher primitives.
- `mahayana-cli/src/bin/mahayana-gateway.rs`: stdio JSON-RPC entry point for the gateway method surface.
- `frontend/apps/web/src/lib/mahayana-host/gateway-events.ts`: surface-facing v1 contract and runtime guard.
- `.github/scripts/check-mahayana-gateway-event-drift.py`: exact Rust/TypeScript event-name parity gate.
- `desktop/src/mahayana-assistant-turn.ts`: ordered reasoning/text/tool/activity parts, legacy/new-event reducers and correct terminal sealing.
- `desktop/src/mahayana-assistant-turn-view.tsx` + CSS: compact natural transcript renderer.
- `desktop/src/messaging-shell-v2.tsx`: active Mahayana operations render as `assistant-turn`; self-hosted Bot command-bridge dispatch/accepted state is joined to that same turn.
- Default Desktop bootstrap no longer mounts `MahayanaAgentInlineReport` or its DOM semantic installer.
- Routine Workbench completion cards are suppressed from the primary transcript; exceptional Inspector states remain during migration.
- Canonical Rust workspace/lock integration for the gateway crates was generated and compiled by Cargo in GitHub Actions.
- Temporary one-shot repair/diagnostic workflow logic used to obtain the compiler failure and verified repair was removed after the verified product commit; the normal `mahayana-fast-checks.yml` gate was restored.

## Verification observed in this execution

Historical failures are retained because they explain the repair and are **not** counted as passing the final head:

1. PR head `2024513d2f54d286499565a6b68f5212ce4c1f31` exposed two product E2E defects: ordinary AssistantTurn stayed `running` after final `chat.message`, and self-hosted Bot invocation did not enter the Messenger AssistantTurn. The Mahayana fast gate also stopped on root `cargo fmt --all -- --check`.
2. A fail-closed repair attempt proved the two source substitutions and formatter path but compilation stopped before any commit. Exact diagnostics from GitHub Actions showed the blocker was runner provisioning: `wayland-sys v0.31.11` could not find `wayland-client.pc` because Linux native development packages were absent.
3. The verification workflow was corrected to install the same Linux native capture/input dependencies already used by the repository's normal Mahayana fast gate. On run `34939951270`, source repair and `cargo fmt --all` passed; `cargo check -p mahayana-gateway -p mahayana-gateway-protocol -p mahayana-cli --bin mahayana-gateway` passed; `cargo test -p mahayana-gateway -p mahayana-gateway-protocol --locked` passed; and the gateway CLI recheck under the generated lock passed.
4. Only after those checks passed did GitHub Actions create product commit `3bcb1dd26353434ad5ee07a16b03bc27d5d37e30` (`fix(msr): complete Hermes assistant turns and Bot routing`).
5. Cleanup commits restored the ordinary fast gate and removed the completed task-specific repair workflow. Those cleanup/project-record commits create a new exact head, so standard CI/E2E must be read again before merge or acceptance.
6. Later exact-head fast checks isolated remaining drift to rustfmt-only changes in `mahayana-cli/src/bin/mahayana-gateway.rs` and `mahayana-gateway-peer/src/lib.rs`; the same repair execution passed the relevant gateway/CLI tests but initially could not push from a shallow checkout.
7. The canonical branch repair was retried with full history. GitHub Actions then created `d49b116facd52be6bc14cd9792e9598a3ab2df9b` (`style(msr): format Hermes gateway peer and refresh lock`) and removed the one-shot repair workflow from the branch. This is a repository commit, not local evidence.
8. Because commits pushed by the workflow `GITHUB_TOKEN` do not recursively start downstream Actions, this project-record commit is intentionally the next user-authored/API commit so the ordinary exact-head PR workflows re-run against the formatted product tree.

No local build result is represented as verification. GitHub Actions exact-head results are the accepted verification source for this task.

## Open blockers before merge / acceptance

1. **Workbench/Inspector split:** normal completion cards are gone, but Workbench still owns identity and exceptional approval/recovery interactions. Separate those responsibilities and remove obsolete portal/timeline coupling without regressing approval/resume/interrupt.
2. **Canonical Rust producer/transports:** the Rust gateway and stdio dispatcher exist, but Desktop/native still consumes the legacy runtime event stream through an adapter. The production host must emit the ordered contract directly and WebSocket/native/stdio must share one dispatcher semantics.
3. **Bidirectional request semantics:** current Hermes main uses server→client JSON-RPC requests with response correlation and open-request replay for approval/clarify/sudo/secret/vault/connection/desktop bridges. Mahayana's first slice does not yet prove those semantics.
4. **Rust session/replay authority:** renderer/App restart ordered-turn restoration is still not backed by one canonical Rust conversation/session store across surfaces.
5. **Latest-upstream delta/full Hermes scope:** the existing matrix was built from the older pinned audit. The latest observed Hermes main is `4d55ca91656ac5f83e1506679b7f81e0238e5e16`, materially newer; remaining `partial`, `audit`, and `missing / unverified` rows (subagent control, slash/completion catalog, skills/memory, MCP/connectors, process/terminal backends, browser/desktop bridge, compression/context, cron/platform gateways and others) remain real work.
6. **Final governance/package proof:** no protected-main merge or fresh canonical-main packaged macOS/Windows/Linux proof exists for MSR-204 yet.

## Verification plan

- Normal Mahayana fast gate: source ownership, Rust/TypeScript drift, root rustfmt, gateway protocol tests, established Mahayana package tests.
- Desktop quality gate: architecture/UI contracts, main-process tests, `npx tsc --noEmit`, renderer build, real Rust Host pre-package user journey, the ordinary Mahayana Hermes-style turn E2E, and self-hosted Bot invocation E2E.
- Producer/session phase: deterministic recorded gateway trace tested over stdio plus Desktop/native transport, disconnect/replay/gap/stale/open-request recovery tests, and Rust-owned restart persistence.
- Source boundary: no Hermes Python runtime/package dependency and no vendor-owned protocol as Mahayana source of truth.
- Product completion: protected-main packaged Electron simulated-user E2E, not a static mock/screenshot.

## Risks / rollback

- Protocol migration can regress mobile/web consumers. Keep the contract additive until cross-surface replay parity exists.
- Dual rendering can duplicate output. One active operation must map to one AssistantTurn; do not reintroduce legacy lifecycle rows as user-visible messages.
- Removing Workbench wholesale would regress approval/resume/interrupt and identity behavior. Split responsibilities before deleting exceptional-state UI.
- Upstream Hermes evolves quickly. Re-pin and re-audit current upstream architecture before making a parity claim.
- Preserve upstream MIT provenance for any substantial copied/ported implementation while keeping Mahayana-owned Rust as the source of truth.

## Evidence

- Draft PR: `#2620`.
- Verified repair run: `34939951270`.
- Verified product repair commit: `3bcb1dd26353434ad5ee07a16b03bc27d5d37e30`.
- Rustfmt repair commit: `d49b116facd52be6bc14cd9792e9598a3ab2df9b`.
- Current capability matrix: `projects/mahayana-sovereign-runtime/management/MSR-204-HERMES-PARITY.md`.
- Final exact-head CI, canonical-main merge SHA, packaged E2E bundle and Release traceability: pending.

## 2026-09-15 canonical continuation

- Re-read canonical PR `#2620` at head `750362aa69b5e61b11abe7b87f49172c432249dc`; this remains the single MSR-204 implementation and duplicate branches must not be revived.
- Exact-head Desktop quality and Host fast E2E were green, while Mahayana fast checks stopped only on `cargo fmt --all -- --check` drift in the gateway CLI and peer crate.
- The CI repair execution proved the formatted source by passing `mahayana-gateway` and `mahayana-cli` tests; its first push failed because the repair checkout was shallow (`shallow update not allowed`), not because product tests failed.
- An initial full-history repair trigger then exposed an invalid YAML `if:` expression before jobs were created; the expression was quoted and retriggered on the same canonical branch.
- The corrected full-history repair succeeded and produced `d49b116facd52be6bc14cd9792e9598a3ab2df9b`, containing the rustfmt changes/lock refresh and deleting the one-shot repair workflow.
- This project-record synchronization is intentionally the next branch commit so the normal PR workflows execute against the repaired tree. Acceptance state remains `in-progress` until those exact-head checks are read and the remaining architectural/product blockers are closed.

### 2026-09-17 release-discovered structured assistant-turn gap

Desktop no-test release run `35218893260` showed that `messaging-shell-v2.tsx` can project structured `assistant-turn` messages into Agent Bot conversations while `BotTranscriptMessage` only admitted message/action/thinking. The current repair models that structured turn and renders it through `MahayanaAssistantTurnView`. This is a compile/projection blocker repair only; MSR-204 remains `in-progress` for the broader Hermes acceptance debt already recorded above.
