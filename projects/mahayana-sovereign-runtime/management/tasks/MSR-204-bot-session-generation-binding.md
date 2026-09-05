# MSR-204 — One Bot -> durable Mahayana session + generation fencing

- Project: `FAB-P0005 / MSR`
- Task ID: `MSR-204`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `1`
- Risk: high; runtime identity/recovery/authorization

## Single objective

Make every Fabushi Bot actor resolve to one durable Mahayana session identity per account and introduce monotonic `session_generation` fencing for mutating execution.

## Dependencies

`MSR-107`; reuse MSR-201/202 concepts but do not mark those broad tasks complete unless their own gates pass.

## Exact implementation allowlist

- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/supervisor.rs`
- `third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-runtime/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-cli/src/main.rs`
- `projects/mahayana-sovereign-runtime/evidence/MSR-204/**`

Forbidden: `native/mahayana-messaging`, GBF device transport, MiniApp backend, vendor product crates outside approved compat adapters, workflows/version files.

## Required contract

`BotRuntimeBinding { account_id, bot_actor_id, mahayana_session_id, session_generation, state, checkpoint_ref, updated_at }`; stable session identity survives recoverable restart; generation increments on a new ownership epoch/reclaim. `ToolExecutionContext` includes account, Bot actor, session id/generation, conversation, invocation/run/correlation, grant id and optional target resource fence.

## Acceptance

1. First invocation creates/resolves exactly one binding; concurrent resolution cannot create two active session identities for the same account/Bot.
2. Restart restores the durable session/checkpoint where valid; ownership epoch change increments generation.
3. Any mutating command with stale generation is denied before tool side effects.
4. Cancellation/approval/tool events preserve session/generation correlation.
5. CLI can inspect the Bot/session binding and resume that session without exposing secrets.
6. Existing generic `mahayana chat <conversation>` and non-Bot sessions remain compatible.
7. Rust tests cover create/race/restart/reclaim/stale generation/cancel paths; exact-head CI and post-main readback required.

## Rollback

Feature-gate Bot binding; rollback may stop new Bot sessions but must not delete stored checkpoints/transcripts. Never roll back by accepting a missing/stale generation on mutations.
