# 2026-09-05 architecture round — MSR

- Revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Baseline: `main@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Round status: `PLANNED`

## WBS delta

| Task | Goal | Depends on | Wave | Status |
|---|---|---|---|---|
| MSR-107 | current-source Codex/Grok Build/Grok Bot evidence audit | MSR-101/102 inputs | 0 | PLANNED |
| MSR-204 | one Bot -> durable Mahayana session + generation fencing | MSR-107, MSR-201/202 concepts | 1 | PLANNED |
| MSR-205 | installed MiniApp discovery/control through common tool policy plane | MSR-204, TFI M8-BIND-001, MSR-401 concepts | 2 | PLANNED |
| MSR-206 | multi-Bot group-turn orchestration runtime | MSR-204/205, TFI M5-BOTGROUP-001, MSR-302 concepts | 3 | PLANNED |

## Acceptance delta

- MSR-NX-A01: upstream audit pins exact commits/licenses/source paths and records adapt/reject decisions; no reconstructed unlicensed code copied.
- MSR-NX-A02: BotRuntimeBinding persists Bot/session/generation and rejects stale-generation mutations.
- MSR-NX-A03: MiniApp capabilities resolve only from current account installs and execute with install digest/permission revision in ToolExecutionContext.
- MSR-NX-A04: group orchestration supports bounded multi-step/multi-participant/multi-result runs and preserves TFI event correlation.

## Dependency/blocker delta

- MSR-204/205/206 remain `PLANNED`; existing Skills or provider adapters do not satisfy them.
- MSR-205 cannot invent MiniApp ownership semantics; it waits for TFI M8-BIND-001.
- MSR-206 cannot invent conversation protocol; it waits for TFI M5-BOTGROUP-001.

## Record correction notes

- Older MSR status says MSR-403 merge is pending, but current `main@586a0952...` is merge #2347. This proves the status file is stale for that task only; it does not promote MSR-201/202/302/401 planned runtime items.
- `docs/08-upstream-capability-matrix.md` pins older Codex/Grok Build commits and must be refreshed by MSR-107 before implementation.

## Changelog

Added master architecture, ADR, this WBS/acceptance/dependency/status delta and four atomic tasks; no runtime code changed.
