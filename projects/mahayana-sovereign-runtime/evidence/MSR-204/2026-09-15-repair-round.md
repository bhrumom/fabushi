# MSR-204 repair round — 2026-09-15

This record binds the repair round to the live draft PR `#2620` and requests the repository-hosted `MSR-204 gateway workspace integration` workflow.

## Bound state

- Canonical `main` observed before this round: `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- PR: `#2620` (`feat/msr-204-hermes-gateway-transcript`).
- PR head observed before repair: `2024513d2f54d286499565a6b68f5212ce4c1f31`.
- Current Hermes upstream main observed during this round: `4d55ca91656ac5f83e1506679b7f81e0238e5e16`.
- Previously pinned Hermes architecture audit remains `5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04` until the upstream delta audit is recorded; no unreviewed upstream code is silently imported.

## Failure-driven repair target

Exact-head/merge-candidate CI showed three directly relevant failures:

1. `Mahayana fast checks` stopped at `cargo fmt --all -- --check` on the newly integrated Rust gateway/CLI files.
2. The normal Messenger Hermes-style assistant turn rendered but remained `running` after the final legacy `chat.message`.
3. The self-hosted `botInvocationRequested` path executed through Mahayana but did not project into the same Messenger `AssistantTurn`, because Messenger did not yet observe the command-bridge dispatch/accepted lifecycle emitted by the existing self-hosted invocation bridge.

The repository-hosted repair workflow is expected to apply only those bounded fixes, run canonical Rust formatting, let Cargo generate the lockfile, compile the gateway/CLI integration, run gateway protocol/replay tests, and commit only after those checks succeed.

## Acceptance for this repair round

- `cargo fmt --all -- --check` no longer fails on the gateway slice.
- Gateway/protocol tests and CLI gateway compilation pass on the resulting exact head.
- Desktop TypeScript/build stays green.
- Real Electron pre-package E2E proves both the ordinary Mahayana prompt and self-hosted Bot invocation finish as one Hermes-style assistant turn, without restoring the routine Workbench completion card.

This evidence record does **not** claim full Hermes parity or task completion. MSR-204 remains in progress until the broader parity matrix, Rust session/replay authority, common stdio/WebSocket/native semantics, protected-main merge, and canonical-main packaged evidence are closed.