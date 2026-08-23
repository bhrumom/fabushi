# GBF-702 — permission/denial/replay security tests

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-702
- Stage: M7-security-provenance
- Objective: 把高风险能力的拒绝路径、重放保护、目标绑定和 fail-closed 行为纳入发布验收。
- Requirements: GBR-004, GBR-005, GBR-007.
- Dependencies: GBF-401..407, GBF-701.
- Status: TESTED (authoritative CI/merge pending)
- Branch: `gbf/m7-security-provenance-closure-20260822-gh`
- Started/Updated: 2026-08-22 19:40+08

## Acceptance
- [x] untrusted IPC / missing handler denial tests exist.
- [x] local-tool permission ceiling and OS-encryption fail-closed tests exist.
- [x] attachment path escape and non-HTTPS denial tests exist.
- [x] computer-control stale generation / wrong device fail-closed tests exist.
- [x] browser target claim/isolation tests exist.
- [x] sensitive-input replay + expiry tests exist.
- [ ] current GitHub security/Electron/Mahayana runs are green.
- [ ] protected merge + canonical main re-read.

## Evidence
`evidence/GBF-702/README.md` plus the executable test suites referenced there.
