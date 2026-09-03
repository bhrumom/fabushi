# GBF-001 — Project Bootstrap

- Task ID: GBF-001
- Objective: 建立“Grok Bot 所有功能/所有源码融合进 Fabushi”的企业级、长期权威项目文件夹。
- Source requirement IDs/references: user source `source/grok-bot融合优化.txt`; GBR-001..010
- Stage: M0
- Status: RELEASED
- In scope: 项目 scaffold、原始来源、规范、WBS、验收、风险、ADR、evidence、runbooks、PR/CI/main 验证。
- Out of scope for this atomic task: 宣称 M1-M8 运行时代码迁移已完成。
- Dependencies: current `main`; verified Grok source branch existence; repository project-folder standard。
- Implementation branch: `project/grok-bot-fabushi-integration`
- Head commit: `4a70e771b9f5f166e49b4001d2d8c9e9ad6164ad`
- PR: #1982
- Required CI: run #6089 / `CI result` = success
- Protected merge: merge queue -> `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c`
- Started: 2026-08-22
- Updated: 2026-08-22
- Completed: 2026-08-22 14:33+08

## Acceptance criteria / checks

- [x] 原始需求保留且 SOURCE_OF_TRUTH 定义优先级。
- [x] 企业标准 required root/docs/management/decisions/evidence/runbooks scaffold 有非空内容。
- [x] 稳定 Requirement ID、Milestone、Task、Risk、ADR 标识建立。
- [x] 每个 required task 有 dependency/acceptance/verification/evidence/status/blocker/next action。
- [x] 历史 Grok latest/0.16 source branches 已确认存在并被标记为 input-only。
- [x] 禁止 wholesale merge；main/source 演进冲突有处理规则。
- [x] Project PR #1982 创建并仅包含本项目目录变更。
- [x] Required CI run #6089 / `CI result` success。
- [x] 通过仓库 merge queue 合并至受保护 main。
- [x] 从 `main` 重新读取项目 `PROJECT.yaml` 与原始 source，确认 canonical state。

## Implementation summary

将最初简版 project folder 扩展为 enterprise-standard 工程项目包；依据 GitHub 实时状态建立 Grok 历史分支 -> current main 的只读审计/原子迁移策略，避免旧分支覆盖后续修复。项目已经具备独立于聊天的目标、需求、架构、质量、安全、发布、运维、M0-M8 路线图、43 个 evidence-gated 原子任务、ADR、runbook 与证据体系。

## Evidence

见 `evidence/GBF-001/README.md`。基线实施 PR #1982、CI #6089、merge commit `6d1e9cd7...` 与 post-merge main read 均已验证。

## Blockers / risks

GBF-001 无 blocker。后续 M1-M8 的来源许可、重复 runtime、computer-control 等风险继续由风险登记和对应原子任务管理。

## Next action

GBF-101：固定精确 refs/SHAs；随后完成来源文件 manifest、能力矩阵、main/source 差异矩阵和 provenance ledger。
