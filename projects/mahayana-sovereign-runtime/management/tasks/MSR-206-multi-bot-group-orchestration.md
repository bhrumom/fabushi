# MSR-206 — Bounded multi-Bot group-turn orchestration

- Project: `FAB-P0005 / MSR`
- Task ID: `MSR-206`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `3`
- Risk: high; concurrent agent orchestration/tool side effects

## Single objective

Execute one canonical TFI GroupTurn as bounded parallel/sequential Mahayana Bot invocations, producing correlated step/tool/partial/final events without creating another conversation or Agent runtime.

## Dependencies

`MSR-204`, `MSR-205`, TFI `M5-BOTGROUP-001`; reuse MSR-302 workflow/subagent concepts without claiming broad MSR-302 completion.

## Exact implementation allowlist

- `third_party/mahayana/mahayana-rs/mahayana-orchestrator/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/supervisor.rs`
- `third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs`
- `projects/mahayana-sovereign-runtime/evidence/MSR-206/**`

Forbidden: TFI conversation schema, Messenger rendering, GBF device transport, vendor orchestration runtime, workflows/version files.

## Acceptance

1. One turn selects an explicit participant allowlist/routing policy and starts each Bot with its current Mahayana session generation.
2. Runtime supports parallel or policy-ordered participants and emits canonical TFI event correlation for each step/result lane.
3. Per-turn max participants/steps/tool calls/time/tokens, cycle detection, bot-to-bot policy, cancellation and approval propagation are enforced.
4. One participant failure/cancel does not erase other terminal results; group terminal state is deterministic.
5. Stale Bot generation or revoked MiniApp/device grant fails only the affected operation and is auditable.
6. Restart/recovery cannot duplicate a completed tool side effect; idempotency keys survive replay where required.
7. CI tests cover 2+ Bots, multiple steps/results, one failure, cancel, stale generation and restart/replay.

## Rollback

Disable multi-Bot orchestration and fall back to single explicit Bot invocation; never discard already-persisted TFI group-turn events.
