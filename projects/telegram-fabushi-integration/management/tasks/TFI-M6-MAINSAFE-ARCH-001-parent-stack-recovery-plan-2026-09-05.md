# TFI-M6-MAINSAFE-ARCH-001 — parent-stack protected-main recovery plan

- Project: `FAB-P0001 / TFI`
- Type: architecture / records-only
- Status: `ARCHITECTURE-PLANNED / EXECUTION-NOT-STARTED`
- Date: 2026-09-05
- Source blocker: test-release records-only PR #2334 (`MERGE-BLOCKED`)

## Goal
Turn the unreviewed `main@688465e... -> codex/tfi-m6-repair@9e88a2e...` parent product delta into a protected-main-safe sequence without retargeting #2323, rewriting its reviewed history, bypassing merge queue, or importing its temporary workflow.

## Frozen architecture decision
Preserve the historical 34-commit stack as immutable evidence. Reconstruct business-semantic end states on fresh branches from the then-current canonical `main`, one layer at a time. Every product layer requires a fresh execution session, a fresh independent review session, exact-head required Actions, protected merge queue, and canonical-main readback before the next layer starts.

## Recovery order
1. `TFI-M6-MAINSAFE-001-RUST-CANONICAL`
2. `TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION`
3. `TFI-M6-MAINSAFE-003-P0-CREATE-JOIN`

FMT/MOD/UNREAD/CLIPPY are not blindly replayed as historical intermediate commits. Their accepted or diagnostic effects are inputs to the appropriate main-safe end-state task; each main-safe task is freshly reviewed as a whole on current canonical main.

## Non-goals
- no app/test/workflow/Cargo/dependency/version edits in this architecture task;
- no retarget/direct merge/force-push/rebase of #2323;
- no merge, canonical E2E, test release or formal release;
- no claim that #2332/#2333/#2334 are merged.

## Evidence
See `evidence/TFI-M6-P0-001/MAINSAFE-PARENT-STACK-ARCHITECTURE-DIAGNOSIS-2026-09-05.md`.

## Closure
This architecture task closes only when the records-only PR exists, its changed files are restricted to `projects/telegram-fabushi-integration/**`, and architecture handoff comments are written to #2323 and #2334. Product execution remains pending.