# TFI-M6-MAINSAFE-001-RUST-CANONICAL execution — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Atomic task: `TFI-M6-MAINSAFE-001-RUST-CANONICAL`
- Group: execution
- Architecture source: records-only PR `#2335@5c88dd6fb577752ccf15c64ed6287c219bfcd13d`
- Test-release blocker source: records-only PR `#2334@b8acbb61292f05ab5addccb59d78ab8dd1d56631`
- Canonical execution base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Branch: `fix/tfi-m6-mainsafe-001-rust-canonical`
- Status at record creation: `EXECUTION-IN-PROGRESS / PR-HEAD-CI-PENDING`

## Frozen scope
Production allowlist:
- `native/mahayana-messaging/src/community.rs`
- `native/mahayana-messaging/src/conversation.rs`
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/service.rs`

Test allowlist:
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`
- `native/mahayana-messaging/tests/unread_projection_contract.rs`

Execution records may be added only under `projects/telegram-fabushi-integration/**`.

Forbidden: Electron task-002 files, any other product/test file, `.github/workflows/**`, Cargo manifests/lock/toolchain/dependencies/lint configuration, release/version files, root `AGENTS.md`, `projects/PORTFOLIO.json`, Project ID changes, and any rewrite/retarget/cherry-pick of the historical #2323 stack.

## Main-based reconstruction
This branch was created directly from exact canonical main `688465e94647d4c866f6b1d7b4884145b2f4a9da`; it was not based on `9e88a2e...`, `1c314ef...`, #2323, or #2335.

Commit `1684cd2d561f1c5c9899cdafde18e35a9f01a00c` reconstructs the six-file historical parent Rust/M6-test end-state by file-level semantic import only. The stable patch-id of `main@688465e... -> historical parent@9e88a2e...` restricted to those six files is `6baf52d50ff641f874a9f2ad34dd44bcaf21ca14`; the reconstruction commit has the same stable patch-id. This is duplicate/equivalence evidence, not a blind cherry-pick.

Per-file parent provenance:
- `community.rs`: `6160971cb3c477b809ae470d60f1e3c601606329`.
- `conversation.rs`: `6160971...`, `dea59a9120b1783764a8b75218341dccedbab54a`.
- `engine.rs`: `6160971...`, `dea59a9...`, `a5eb431375588068611a1b74a1ef2b2f6d215f23`, `e7b41cd70f06242175384055b24449abc372232b`, `af6fb35c30f9d64d6f731c8a0d1ebef959f95a73`.
- `protocol.rs`: `6160971...`.
- `service.rs`: `6160971...`, `dea59a9...`, `a5eb431...`, `f9316f500d0ef4ee27937dfdb70051436f308986`, `e7b41cd...`, `ff07289fad62ccc896cc372a491b174e37d6ab52`, `9916a77ed5941538c81e0cdb5884a3bee0b59ff5`, `af6fb35...`.
- `m6_channels_topics_contract.rs`: `6160971...`, `a5eb431...`.

Commit `eb0891a9bb67daae334da322770084097e5e733c` preserves only the reviewed Rust-boundary continuity effects:
- FMT source `d2f97c0c22411a49ef926c0bb9c049be18348b10`, patch-id `79cbbb7547b4fc7b46116519232dfe5f34227edf`; only formatter hunks compatible with the parent Rust state were used. Rejected historical hunks belonged to later P0 code that is absent here.
- MOD source `a058b3adba5e20fccd19af06398cca19b8987074`, patch-id `5678659e79ed90f4e7b6c4caa7de54ea9b562878`, plus formatter `460d08b380b1b9dca5bdab4d37c75f5cb83f1fc1`, patch-id `ed102a0f05ad5cffa5d0e0a89238d9a88974a0a3`.
- UNREAD source `7d158e1742b2d9e56d101c90d3d81408dcd41947`, patch-id `1cdbd1d45d774f5fa36bf872c1d09bc2727a3077`.
- CLIPPY source `90d337e8d04ce8c463c7228cac1053158f8268ed`, patch-id `2209edfac9703c03213f5abe6b92da76a8de5345`, plus formatter `0899258257e2efb8c24bb7fa951f4ae6180bbb10`, patch-id `02d01d946b3e7aeb3f391d628d21cf738c4917b9`.

## Frozen semantic checks before CI
- `CommunityState.members` remains Group/Channel policy authority; participant mutations converge to Conversation compatibility projection.
- `CommunityState.topics` remains canonical and recipient projection remains in service boundary.
- shared journal remains recipient-neutral under the historical parent state.
- MOD: after ban, send contract is `EngineError::SenderNotParticipant`; banned member is absent from conversation participants; slow-mode/topic/member admin-log assertions remain.
- UNREAD: Group management fixture creates same-ID Community authority using public `ClientCommand::UpdateCommunity`; existing management boundary assertions remain in the test.
- CLIPPY: private `CommunityAdminAction::PostMessages` selector/mapping is absent; `AdminRights.post_messages` and live Channel-send authorization remain; removal guard keeps Owner/Administrator target check, `!caller_is_owner`, and exact denial text `admins cannot remove owner/admin members`.
- No task-003 create/join semantic hunk was imported.

## Open-source-first / official basis
This recovery adds no external implementation code and no dependency. The reconstruction method follows the architecture record's official Git/GitHub basis: Git patch identity (`git patch-id --stable`) and ancestry/diff comparison for duplicate detection, plus GitHub protected merge/required-check semantics for acceptance. Historical source code is internal Fabushi provenance; no TDLib/Grok/Codex implementation is copied or adapted by this task. Any external code/dependency would trigger the frozen supply-chain stop rule.

## Stop rules
Stop `SCOPE-EXPANSION-REQUIRED` if any product/test file outside the seven-file allowlist, workflow, Cargo/dependency/toolchain/lint/version/release change is needed. Stop `ARCHITECTURE-MERGE-BLOCKED` for a new semantic/security/supply-chain failure or inability to keep a clean main-based diff. Do not proceed to task 002/003, merge, packaged E2E, test release or formal release in this execution session.

## Verification policy
No local build, test, rustfmt, clippy, Electron, native app or E2E execution is permitted or used. Only text/diff/patch-id checks were performed locally. Heavy verification must come from GitHub Actions on the exact PR head.
