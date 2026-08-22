# GBF-001 — Project Bootstrap

- Task ID: GBF-001
- Objective: 建立“Grok Bot 所有功能/所有源码融合进 Fabushi”的企业级、长期权威项目文件夹。
- Source requirement IDs/references: user source `source/grok-bot融合优化.txt`; GBR-001..010
- Stage: M0
- Status: IN_PROGRESS
- In scope: 项目 scaffold、原始来源、规范、WBS、验收、风险、ADR、evidence、runbooks、PR/CI/main 验证。
- Out of scope for this atomic task: 宣称 M1-M8 运行时代码迁移已完成。
- Dependencies: current `main`; verified Grok source branch existence; repository project-folder standard。
- Branch: `project/grok-bot-fabushi-integration`
- Commits: `c7086a10df514e78787cbdcf57cd0ee80bf4f444`, `b03cfeea7e4b0aa7574eccd59ba82cbcfd8f320b`, `f214c1dd98d5e61055f100305d1fb3adb215f260` plus current enterprise-alignment commit when created
- PR: pending
- Started: 2026-08-22
- Updated: 2026-08-22
- Completed: —

## Acceptance criteria / checks

- [x] 原始需求保留且 SOURCE_OF_TRUTH 定义优先级。
- [x] 企业标准 required root/docs/management/decisions/evidence/runbooks scaffold 有非空内容。
- [x] 稳定 Requirement ID、Milestone、Task、Risk、ADR 标识建立。
- [x] 每个 required task 有 dependency/acceptance/verification/evidence/status/blocker/next action。
- [x] 历史 Grok latest/0.16 source branches 已确认存在并被标记为 input-only。
- [x] 禁止 wholesale merge；main/source 演进冲突有处理规则。
- [ ] Project PR 创建并记录。
- [ ] Required `CI result` 通过。
- [ ] 通过仓库 required protected-main/merge queue 流程合并。
- [ ] 从 `main` 重新读取项目目录并确认 canonical state。

## Implementation summary

将最初简版 project folder 扩展为企业级工程项目包；同时依据 GitHub 实时状态建立 Grok 历史分支 -> current main 的只读审计/原子迁移策略，避免旧分支覆盖后续修复。

## Evidence

见 `evidence/GBF-001/README.md`。PR/CI/merge/main verification 尚待补充，因此状态保持 IN_PROGRESS。

## Blockers / risks

当前仅剩仓库外部验收门：PR、CI、protected main、post-merge main verification。R1/R2/R9 继续开放。

## Next action

完成 enterprise scaffold audit，创建 PR，检查 required CI 并按受保护 main 流程推进。
