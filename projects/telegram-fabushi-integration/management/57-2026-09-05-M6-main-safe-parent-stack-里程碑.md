# 57 — 2026-09-05 M6 protected-main-safe recovery milestones

## M0 Architecture frozen
- exact 12-commit parent ancestry recorded;
- #2323 child scope/review limits recorded;
- recovery task allowlists/stop rules frozen;
- records-only PR and #2323/#2334 handoff exist.

## M1 Rust canonical accepted
`TFI-M6-MAINSAFE-001-RUST-CANONICAL` has fresh independent review PASS, exact-head required Actions PASS, protected merge-queue acceptance and exact canonical-main readback.

## M2 Electron projection accepted
`TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` repeats the same review/Actions/queue/readback cycle on M1 canonical main.

## M3 P0 residual accepted or proven empty
`TFI-M6-MAINSAFE-003-P0-CREATE-JOIN` is either protected-merged after fresh review/Actions or records `ALREADY-IN-MAIN` with auditable equivalence proof.

## M4 Test-release restart eligible
Only after M1-M3 and a fresh canonical readback may test-release create a legal main merge/test delivery path and begin canonical packaged E2E. This document does not authorize that action now.