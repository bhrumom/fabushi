# 2026-09-05 architecture round — TFI

- Revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Baseline: `main@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Round status: `PLANNED`

## WBS delta

| Task | Goal | Depends on | Wave | Status |
|---|---|---|---|---|
| M3-DESKTOP-003 | instrument/reproduce first-message startup bottleneck | M3-DESKTOP-002 | 0 | PLANNED |
| M3-DESKTOP-004 | fix measured critical path | M3-DESKTOP-003 | 1 | PLANNED/BLOCKED |
| M8-ENTITY-001 | durable MiniApp definition/version/install model | existing M8 marketplace/account sync | 0 | PLANNED |
| M8-BIND-001 | one install -> one Bot actor/direct conversation | M8-ENTITY-001 | 1 | PLANNED |
| M8-CARD-001 | generated MiniApp entity/card projection + install/open actions | M8-ENTITY-001, M8-BIND-001, M3-DESKTOP-004 | 2 | PLANNED |
| M5-BOTGROUP-001 | canonical multi-Bot group-turn event protocol | M8-BIND-001 | 2 | PLANNED |

## Acceptance delta

- TFI-NX-A01: packaged returning-user trace identifies P0-P9 and the critical bottleneck; cached first interactive and first visible message batch are <1000 ms after fix, bounded initial hydration <2000 ms.
- TFI-NX-A02: Bot-generated MiniApp has a durable entity/version/digest and a card reference; card state survives restart/account sync.
- TFI-NX-A03: each current account MiniApp install has exactly one default Bot actor + one direct conversation and auditable permission/update/uninstall/restore history.
- TFI-NX-A04: group turns preserve multiple Bot participant step/result lanes with deterministic correlation/order.

## Dependency/blocker delta

- M3-DESKTOP-004 is fail-closed until M3-DESKTOP-003 names the measured critical path. If the bottleneck requires a file outside its allowlist, return to architecture.
- M8-CARD-001 waits for the startup task because both may own `desktop/src/messaging-shell-v2.tsx`.
- M5-BOTGROUP-001 provides protocol only; runtime orchestration depends on MSR-206.

## Record correction notes

- M8-MARKET-002 text still says PR #2158 merge/readback remains; GitHub shows #2158 merged. Treat old task prose as stale administrative state, not evidence that Bot projection is absent.
- The M8 split WBS contains older NOT_STARTED rows for capabilities now partially present in main; implementation truth must be re-read from current code per task.

## Changelog

Added this architecture-round delta and six atomic tasks; no product code changed.
