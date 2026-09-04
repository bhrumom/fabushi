# ADR-0014 — TFI uses MSR as the only Bot runtime and GBF as behavior/capability contract owner

- Project: `FAB-P0001/TFI`
- Program: `FAB-ARCH-P0-20260904`
- Status: Proposed for protected-main review
- Date: 2026-09-04

## Decision

TFI owns messaging and MiniApp projections but does not own a Bot execution engine. Every Bot identity maps to exactly one durable Mahayana session owned by FAB-P0005/MSR. Conversation/group/topic context is scoped within that session. TFI may render Bot identity, transport invocations and typed tool results, but cannot spawn a parallel runtime.

MiniApp installation derives its Bot projection from canonical catalog/manifest metadata and binds that identity to MSR. Same-account device control and MiniApp semantic capability discovery use FAB-P0004/GBF contracts through MSR policy/approval; TFI does not add direct privileged execution.

Grok Bot reconstructed material is clean-room behavior reference only when a root source license is absent. No unlicensed implementation is copied.

## Consequences

- Eliminates duplicate Bot/contact/runtime state machines.
- Makes install->Bot->Mahayana session testable across projects.
- Requires cross-project acceptance before TFI-M8-P0-002 or TFI-M7-P0-001 can close.

## Alternatives rejected

- Per-conversation Bot runtimes: rejects 1 Bot : 1 session invariant and fragments recovery.
- MiniApp-owned hidden Bot engine: duplicates MSR policy/tools.
- Direct Grok Bot source copy: rejected by provenance/license boundary.