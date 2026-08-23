# GBF-701 — IPC/Host threat model

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-701
- Stage: M7-security-provenance
- Objective: 固化 renderer/preload/main/AppHost/FeatureHost/runtime/remote-control/browser/sensitive-input 的信任边界、威胁、缓解和残余风险。
- Requirements: GBR-004, GBR-005, GBR-007.
- Dependencies: GBF-201..205, GBF-401..407, GBF-603.
- Status: TESTED (CI/merge pending)
- Branch: `gbf/m7-security-provenance-closure-20260822-gh`
- Started/Updated: 2026-08-22 19:40+08

## Acceptance
- [x] 至少七个 trust boundaries 明确记录。
- [x] privilege escalation、confused deputy、replay/target drift、wrong-tab、secret leakage、path traversal、provenance 风险均有 mitigation + residual risk。
- [x] 机器 gate 校验 threat inventory 完整性。
- [ ] GitHub CI 通过。
- [ ] protected merge + canonical main re-read。

## Evidence
`evidence/GBF-701/threat-model.json` and `evidence/GBF-701/README.md`.
