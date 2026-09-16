# UNREAD-001 open-source-first evidence — 2026-09-05

Scope: conversation unread projection, owner/admin/removal boundaries, Group/Community membership authority, state/fixture isolation and test-order discipline. This review adopts concepts only; no upstream code is copied, translated, ported or adapted.

## Candidate 1 — matrix-org/matrix-rust-sdk
- Project: maintained Matrix client SDK in Rust; production use documented by upstream.
- License: Apache-2.0.
- Relevant architecture: room membership/state and unread projections are explicit room state, persisted through a state store; current SDK APIs distinguish room/member state and power-level authorization rather than treating a display list as the authority.
- Relevant testing lesson: create/restore the authoritative room state before asserting derived room lists/unreads/permissions; keep test stores isolated.
- Fabushi decision: **BORROW CONCEPTS ONLY**. Strong language/runtime compatibility (Rust) and permissive license, but Fabushi already has its own engine/service/state contracts, so importing an SDK or code would add unnecessary protocol/runtime coupling.

## Candidate 2 — matrix-org/complement
- Project: maintained Matrix compliance/integration test suite.
- License family: Apache-2.0 in the Matrix ecosystem/project repository; no code is imported here.
- Relevant test patterns: explicit room membership setup before kick/leave/visibility assertions; negative cases such as a user outside a room being unable to kick, and departed-room visibility behavior. This reinforces testing management semantics from a valid authoritative membership fixture rather than relying on an unrelated projection.
- Fabushi decision: **BORROW TEST-BOUNDARY IDEAS ONLY**. Go/integration harness is not compatible with Fabushi's Rust unit/contract layer and no new external harness is needed for this blocker.

## Candidate 3 — continuwuity/continuwuity
- Project: actively maintained Matrix homeserver written in Rust.
- License: workspace declares `Apache-2.0`.
- Relevant architecture: server-side Matrix state/membership is authoritative and tied to room state resolution/authorization, aligning conceptually with Fabushi's Community-backed Group membership authority.
- Fabushi decision: **BORROW AUTHORITY-SEPARATION IDEA ONLY**. Rust and license are compatible, but its Matrix server state-resolution/storage stack is much broader than this one-test fixture repair and is therefore rejected as a dependency or code source.

## Candidate 4 — element-hq/synapse
- Project: maintained Matrix homeserver, primarily Python/Twisted with Rust components.
- License: AGPL-3.0 or separate commercial license.
- Relevant architecture/testing: membership changes are represented in authoritative room state streams; permission and membership tests establish room state before exercising management transitions.
- Fabushi decision: **REFERENCE/REJECT CODE REUSE**. Useful conceptual boundary evidence, but AGPL/commercial licensing and runtime mismatch make code reuse inappropriate for this task.

## Result for Fabushi
The external review supports the existing Fabushi direction rather than replacing it:
1. membership/authorization state must have one authoritative domain representation;
2. unread/visible conversation projections are derived views, not permission authority;
3. tests that exercise member administration must first create the authoritative room/community state;
4. each contract test should use isolated state and avoid depending on test order or previous fixtures.

Therefore UNREAD-001 uses Fabushi's already-existing public `UpdateCommunity` path to create a valid Community-backed Group fixture and changes no production semantics. No upstream implementation code will be copied.
