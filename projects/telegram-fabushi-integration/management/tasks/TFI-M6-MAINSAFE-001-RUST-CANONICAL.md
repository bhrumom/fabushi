# TFI-M6-MAINSAFE-001-RUST-CANONICAL — rebuild canonical M6 Rust boundary from main

- Project: `FAB-P0001 / TFI`
- Type: product-code atomic task
- Priority: P0 / bottom-of-stack
- Status: `READY-AFTER-ARCHITECTURE-HANDOFF`
- Owner model: one fresh execution-group session; then one fresh independent code-review session

## Purpose
Reconstruct the smallest independently reviewable Rust M6 canonical state-machine boundary on the then-current protected canonical `main`. This is not a cherry-pick sequence. Historical commits are immutable source provenance; the execution result is a fresh main-based semantic end-state.

## Historical provenance
Primary parent source: `6160971...`, `dea59a9...`, `a5eb431...`, `f9316f5...`, `e7b41cd...`, `ff07289...`, `9916a77...`, `af6fb35...` (records checkpoints excluded as code sources).
Required child continuity inputs where they affect this frozen Rust/test boundary: FMT `d2f97c0...`, MOD semantic contract alignment, UNREAD fixture `7d158e1...`, CLIPPY `90d337e...` + formatter `0899258...`.

## Frozen file allowlist
Production:
- `native/mahayana-messaging/src/community.rs`
- `native/mahayana-messaging/src/conversation.rs`
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/service.rs`

Tests:
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`
- `native/mahayana-messaging/tests/unread_projection_contract.rs`

No other production/test file is authorized. In particular: no Electron source, `.github/workflows/**`, Cargo/dependency, version, release or generated-package changes.

## Frozen behavior boundary
- Channel subscription/audience, bounded member/audit paging, Topic state/draft/read behavior and slow mode.
- Community admission must not synthesize missing state for outsiders; private/public semantics remain server-authoritative.
- `CommunityState.members` is policy authority for Group/Channel membership; Conversation participants are compatible projection, with owner/admin/ban/leave/approval mutations converged.
- `CommunityState.topics` is canonical; Conversation topics are a recipient-scoped compatibility projection.
- Shared journal remains recipient-neutral: no bearer invite token, pending join request, admin log or actor-local unread leakage; replay projects for recipient.
- Community-backed generic update cannot bypass canonical membership/topic authority.
- Preserve the validated MOD post-ban send contract, UNREAD fixture alignment, and CLIPPY cleanup in the final main-based Rust state.
- No protocol-version expansion beyond historical parent end-state; if current main makes v2/v3 compatibility unsafe, STOP instead of broadening scope.

## Execution method
1. Re-read canonical main and verify it still contains none/equivalent subset of this patch.
2. Build a source-provenance table mapping every intended hunk to historical SHA(s).
3. Reconstruct only the final semantic end-state in the frozen allowlist. Do not blindly cherry-pick the historical chain.
4. Use `git patch-id`, `git range-diff`, or equivalent source-vs-reconstruction comparison as audit evidence; patch identity alone does not replace semantic review.
5. Push a main-based product PR whose base is the then-current canonical main.

## Acceptance / Actions
- Diff contains only the seven allowlisted files plus TFI records written by that execution task.
- Fresh independent code review explicitly audits the full main-based diff; no prior FMT/MOD/UNREAD/CLIPPY PASS is reused as full-parent acceptance.
- Repository required Actions are green on exact execution head, including required `CI result`; messaging Rust formatter, all-target tests, messaging clippy `-D warnings`, M6 contract, unread contract, and downstream required bridge/media checks must actually execute/pass if present in current CI.
- Protected main merge uses the active queue; after acceptance, canonical main is read back and becomes the only base for task 002.

## Stop rules
STOP as `ALREADY-IN-MAIN` if the intended semantics are already patch-equivalent on current main.
STOP as `SCOPE-EXPANSION-REQUIRED` if any production/test file outside the seven-file allowlist is required, or if workflow/Cargo/dependency/version changes are required.
STOP as `ARCHITECTURE-MERGE-BLOCKED` for a new semantic/security/supply-chain failure or if a clean independently reviewable main-based diff cannot be produced.
Do not proceed to task 002 on red/pending required CI, review rejection, merge conflict, or absent exact canonical-main readback.