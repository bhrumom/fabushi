# ADR — Single Mahayana Bot session + target fencing

- Status: Accepted for planning (`PLANNED` implementation)
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`

## Decision

1. Mahayana is the only Fabushi Agent runtime product core. Each Bot actor owns one durable Mahayana session identity per account.
2. `session_generation` is a monotonic ownership/fencing epoch and is mandatory on mutating tool executions.
3. TFI remains authoritative for actors/conversations/messages/MiniApp install semantics; GBF remains authoritative for device-control transport/security; MSR binds them through a common ToolExecutionContext.
4. MiniApps are durable entities/installs with a default Bot binding, not a second Agent runtime.
5. Group multi-Bot execution is a correlated set of Bot invocations inside one canonical conversation; it does not create a second group runtime.
6. Grok Build/Codex are capability sources behind Fabushi-owned contracts. Grok Bot reconstructed source is evidence-only.

## Consequences

- Stale Bot sessions cannot mutate devices or MiniApps even when the device session itself is still live.
- A Bot restart can recover its durable session while incrementing generation when ownership changes.
- Device and MiniApp audits can reconstruct `who/which Bot session/which conversation/which target/which permission` for every mutation.
- Implementation remains `PLANNED` until task gates pass.
