# GBF-704 — secret/log/privacy audit

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-704
- Stage: M7-security-provenance
- Objective: 对 secret handling、structured logs、diagnostics persistence、sensitive input 和 unnecessary persistence 做最终隐私闭环。
- Requirements: GBR-005, GBR-007.
- Dependencies: GBF-603, GBF-702.
- Status: TESTED (CI/merge pending)
- Branch: `gbf/m7-security-provenance-closure-20260822-gh`
- Started/Updated: 2026-08-22 19:40+08

## Acceptance
- [x] Electron edge telemetry excludes args/results/URLs/tokens.
- [x] native diagnostics recursively redact sensitive keys and behavior is covered by test.
- [x] Secret Vault requires OS-backed encryption and never lists secret values.
- [x] sensitive input is encrypted, challenge-bound, expiring/one-time and rotated on reconnect.
- [x] security closure gate rejects removal of these boundaries.
- [ ] GitHub security closure / Electron / computer-control evidence green.
- [ ] protected merge + canonical main re-read.

## Evidence
`evidence/GBF-704/README.md` plus GBF-603/GBF-406 executable test evidence.
