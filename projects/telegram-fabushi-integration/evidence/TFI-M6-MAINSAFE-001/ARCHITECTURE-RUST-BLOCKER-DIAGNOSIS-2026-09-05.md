# TFI-M6-MAINSAFE-001 — architecture Rust blocker diagnosis evidence — 2026-09-05

Status: `ARCHITECTURE-RUST-BLOCKER-DIAGNOSED / NEXT-ATOMIC-TASK-FROZEN`.

## Authority and topology readback
- Repository: `bhrumom/fabushi`.
- Canonical main read from GitHub at diagnosis freeze: `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Architecture source PR #2335: base canonical main, exact records head `5c88dd6fb577752ccf15c64ed6287c219bfcd13d`; it freezes strict `001 Rust canonical -> 002 Electron projection -> 003 P0 create/join` ordering.
- Product PR #2336: open/unmerged, base `688465e94647d4c866f6b1d7b4884145b2f4a9da`, diagnosed exact head `115cd55065d03b66f14d7e086d454709d24d2286`.
- #2336 is a six-commit main-based chain. Its first product commit `1684cd2d...` has canonical main as parent; it is not the historical #2323 34-commit stack.
- Changed-files at the diagnosed head are exactly the frozen seven Rust source/test files plus four TFI execution records. No out-of-allowlist product/test file was observed.

## Execution stop-rule provenance
The execution evidence records an initial rustfmt failure, a second deterministic compile mismatch repaired on the next product commit, and explicitly freezes any third deterministic Rust failure as a stop condition. The exact head `115cd550...` then produced the current ownership compile errors. Therefore the original execution session correctly returned `MAINSAFE-RUST-BLOCKED / SCOPE-EXPANSION-REQUIRED` rather than continuing opportunistically.

Historical run `33914142883` belongs to earlier head `219c3e7b...` and is the formatting-only baseline repaired by `d105944...`. It is not the current ownership blocker.

## Exact-head Actions evidence
### Messaging Product Gate — run `33914564827`
- Electron Messenger contract current job `101158639006`: PASS.
- Rust self-hosted product job `101158638727`: FAIL.
- `cargo fmt --manifest-path native/mahayana-messaging/Cargo.toml -- --check`: PASS.
- `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets`: compile FAIL in `fabushi-messaging-core`.
- Messaging Clippy and later Rust steps: SKIPPED, so no Clippy acceptance exists.
- Compiler diagnostics:
  - E0505 at `src/engine.rs:1789:30`: `Command::SubscribeChannel`, `actor_id` is borrowed as `&actor_id` for `append_community_audit` and moved into `Some(actor_id)` in the same call.
  - E0505 at `src/engine.rs:1825:30`: `Command::UnsubscribeChannel`, identical borrow/move shape.
  - E0382 at `src/engine.rs:2204:30`: `Command::RespondCommunityJoin`; `requester_id` was moved into audit target at the approved/rejected audit call around lines 2171/2185 and is later borrowed by `community.members.get(&requester_id)` for participant projection.
- Result: `m6_channels_topics_contract` and `unread_projection_contract` did not dynamically execute; compile failure is not a contract PASS.

### Fabushi self-hosted messaging — run `33914564790`
Current latest-attempt readback differs from the stale execution-summary job status:
- Rust messaging core `101158721014`: FAIL; rustfmt PASS, unit/contract step fails compiling the same messaging core, Clippy skipped.
- Mahayana social -> messaging Actor `101158720692`: FAIL; its real-contact projection build reaches the same `fabushi-messaging-core` ownership diagnostics. This is a downstream/derived failure at this baseline, not evidence of a separate Actor defect.

### Mahayana fast checks — run `33914564807`
- Job `101158616359` passes source ownership boundary, formatter, CLI, auth/secrets, product client, kernel/legacy bridge, orchestration/workspace, model/coding agent, MCP/Agent adapter and protocol/MiniApp bridge steps.
- It then fails at `Test Rust-native Mahayana Harness` because that harness build reaches the same `fabushi-messaging-core` compilation diagnostics.
- Direct Host and later fast-gate steps are skipped after the harness failure.
- Architecture classification: **derived failure** from the same messaging-core compile blocker. It is included in the ownership repair acceptance rather than split now. If an exact repaired head compiles messaging core and the harness then fails for a different reason, execution must stop and return a new independent blocker.

### Green but non-substitutive exact-head workflows
Current exact-head GitHub readback:
- CI `33914564928`: SUCCESS; current `CI result` job `101158917285` PASS.
- Explicit automerge `33914564792`: SUCCESS.
- Developer Fiat Commerce `33914564803`: SUCCESS.
- Project portfolio governance `33914564951`: SUCCESS.
These do not override the red Rust product/self-hosted/fast workflows.

The handoff's older auxiliary run/job IDs are retained as historical snapshot data only where records mention them; exact-head workflow name + current GitHub run/latest-attempt job readback is used for acceptance.

## Root-cause analysis
`append_community_audit` encodes a deliberate ownership distinction:
- `actor_id: &ActorId` is a borrowed acting identity; the helper clones it when constructing the retained audit entry.
- `target_actor_id: Option<ActorId>` is an owned identity stored by the audit entry.

The three errors all violate this same boundary. The command-bound canonical ID is still semantically needed for permission/state lookup or later compatibility projection, but the call site transfers that same owner into an audit payload too early. The borrow checker correctly prevents simultaneous borrow-and-move (E0505) and later use-after-move (E0382).

The repair design is therefore one minimal ownership repair, not three semantic changes: preserve the command identity as the canonical owner used by the existing flow and produce an independent owned identity only for the retained audit-target payload. No control-flow reorder, helper/API redesign or business semantic change is needed.

`ActorId` is a `Clone`-capable newtype over `String` and is not `Copy`; making a String-backed identity `Copy` is neither available nor an appropriate domain change. Shared ownership (`Rc`/`Arc`) would broaden the design without solving a need evidenced here.

## Open-source-first comparison and license/source disposition
1. **Rust official E0505 documentation** — source: `https://doc.rust-lang.org/stable/error_codes/E0505.html`. It defines the error as moving a value while an outstanding borrow still needs it and recommends avoiding the move, ending the borrow, or using an ownership model appropriate to the type. **Disposition:** adopt principle only; no code copied.
2. **Rust official E0382 documentation** — source: `https://doc.rust-lang.org/stable/error_codes/E0382.html`. It describes later use after ownership transfer and explains borrowing or explicit cloning/shared ownership when genuinely required. **Disposition:** adopt the ownership reasoning only; no code copied.
3. **Ruma / Matrix Rust identifier design** — sources: `https://docs.rs/ruma-common/latest/ruma_common/` and `https://docs.rs/ruma-common/latest/ruma_common/user_id/struct.UserId.html`. Ruma exposes a borrowed `UserId` and an `OwnedUserId`, with `ToOwned` converting at owned boundaries. Ruma's repository is MIT-licensed (`https://github.com/ruma/ruma`). **Disposition:** adopt the architectural pattern—borrow stable identity for lookup, materialize owned identity at retained payload boundaries—without importing types, copying code or adding a dependency.

License/supply-chain conclusion: this diagnosis copies no upstream implementation and adds no dependency, so there is no new third-party code or Cargo/license surface. Any future proposal to import code/dependencies is outside this atomic task and triggers architecture/supply-chain review.

## Frozen repair
Next task: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001.md`.

Production allowlist: exactly `native/mahayana-messaging/src/engine.rs`.
Records allowlist: `projects/telegram-fabushi-integration/**` for factual execution evidence/status/handoff only.

No test source, other Rust production file, Electron file, workflow, Cargo/dependency, version or release file is authorized.

## Gate consequence
No PASS is asserted for parent MAINSAFE-001. Code review, merge, canonical-main E2E, test release and formal release are all blocked. MAINSAFE-002 and MAINSAFE-003 remain locked by the previously frozen canonical-readback chain.
