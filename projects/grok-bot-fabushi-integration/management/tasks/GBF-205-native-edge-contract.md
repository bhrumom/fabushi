# GBF-205 — 收敛 native/edge IPC schema 与错误合同

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-205
- Objective: 收敛 native/edge IPC schema 与错误合同。
- Source requirement IDs/references: GBR-002, GBR-004; `source/grok-bot融合优化.txt`; M1 evidence.
- Stage: M2
- Status: TESTED (GitHub CI/merge pending)
- In scope: 当前 `main` 与 pinned Grok source 的能力级差异、正式 Fabushi/Mahayana 归属、实现/测试/CI/证据。
- Out of scope: wholesale merge 历史 Grok 分支；把 vendor 0.20 二进制/构建产物重新带回生产。
- Dependencies: GBF-202.
- Implementation branch: `gbf/m2-electron-host-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:03+08
- Updated: 2026-08-22 17:09+08
- Completed: —

## Acceptance criteria

- [x] edge method/event catalog 唯一；unknown event/handler/trust failure 可确定；dispose 无残留 handler。
- [x] 相关拒绝/错误/恢复路径有客观验证。
- [ ] GitHub Actions required checks 通过。
- [ ] merge queue 合入 main 并完成 post-merge verification。

## Verification

edge-ipc unit tests + parity gate.

## Implementation / local verification

本轮实现与轻量验证已通过；权威 CI/merge 仍待 GitHub。

## Evidence

`evidence/GBF-205/`（实现后补 commit/PR/CI/test/main verification）。

## Risks

R1/R3/R4/R9/R10；涉及本机能力时同时受 R5/R6。

## Next action

执行当前 main/source audit，修复真实缺口并补最小自动化测试。
