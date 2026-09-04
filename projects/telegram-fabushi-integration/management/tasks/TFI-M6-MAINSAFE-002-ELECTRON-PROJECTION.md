# TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION — rebuild Electron M6 consumer/projection from accepted main

- Project: `FAB-P0001 / TFI`
- Type: product-code atomic task
- Priority: P0 / layer 2
- Status: `BLOCKED-BY-TFI-M6-MAINSAFE-001-RUST-CANONICAL`
- Owner model: one fresh execution-group session; then one fresh independent code-review session

## Dependency
Must start only after task `TFI-M6-MAINSAFE-001-RUST-CANONICAL` has passed fresh review, exact-head required Actions, protected merge queue, and exact canonical-main readback. The accepted canonical main SHA is the only permitted base.

## Historical provenance
Electron source behavior derives from parent product commits beginning at `6160971...`, with projection continuity/fixes at `ff07289...` and `9916a77...`. Records-only commits are evidence, not code sources.

## Frozen file allowlist
Production only:
- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/src/messaging-shell-v2.tsx`

No Rust source/test, workflow, Cargo/dependency, version or release file is authorized.

## Frozen behavior boundary
- Client typings/commands consume the accepted Rust Community/channel/topic protocol surface without inventing a second authority.
- `communityChanged` projects canonical Community topics into the matching conversation shape using the exact Electron field mapping (`creatorId -> createdBy`) and preserves/uses recipient-local unread semantics correctly.
- Snapshot/delta consumers handle M6 member/audit/topic-draft/topic-read payloads exposed by the accepted Rust layer.
- No privileged state may be widened or reconstructed from another actor's public mutation.
- No UI feature expansion beyond the historical two-file consumer/projection end-state.

## Execution method
1. Re-read the accepted canonical main from task 001.
2. Compare the two historical parent files against current main and stop if already equivalent.
3. Reconstruct the final Electron consumer/projection semantics only in the two allowlisted files; record source SHA/hunk provenance.
4. Open a fresh main-based product PR.

## Acceptance / Actions
- Product diff is exactly the two allowlisted Electron files plus TFI execution records.
- Fresh independent review audits protocol shape compatibility, recipient-scoped projection and no authority widening.
- Required current Actions are green on exact head; Electron/messaging frontend typecheck/tests and repository required `CI result` must pass.
- Protected merge queue only after review PASS + required Actions; exact accepted canonical main must be read back before task 003.

## Stop rules
STOP `ALREADY-IN-MAIN` on equivalent current-main behavior.
STOP `SCOPE-EXPANSION-REQUIRED` if any third production file, any Rust/test file, workflow/Cargo/dependency/version file, or new UI surface is needed.
STOP `ARCHITECTURE-MERGE-BLOCKED` on protocol mismatch, security/privilege regression, review rejection, red required CI, or inability to produce an independent main-based two-file diff.