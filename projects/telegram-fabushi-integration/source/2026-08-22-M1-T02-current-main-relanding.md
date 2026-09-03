# M1.T02 current-main re-landing source record

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M1.T02`
- **Date**: `2026-08-22`

## Source requirement

Continue FAB-P0001 until the Telegram-to-Fabushi integration is fully landed. For M1.T02, production messaging storage must use the self-owned Rust/SQLite path and preserve safe migration from the historical JSON snapshot.

## Execution clarification discovered during this round

PR #1990 contains the intended storage implementation but also carries project-document versions from before immutable portfolio IDs (`FAB-P0001 / TFI`) were established on canonical `main`. Those stale project records must not be merged over the current project baseline.

Therefore the implementation is being re-landed from current `main` on `feat/telegram-m1-sqlite-main-sync`, carrying only the intended M1.T02 runtime change and fresh durable task/evidence records. This is an execution correction, not a scope change.
