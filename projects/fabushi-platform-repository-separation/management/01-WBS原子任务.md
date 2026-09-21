# WBS 原子任务

| ID | 原子任务 | 验收 | 状态 | 下一步 |
| --- | --- | --- | --- | --- |
| PRS-001 | 项目登记、canonical SHA 和平台盘点 | 注册表/项目脚手架/矩阵齐全 | passed | 记录合入 SHA，转入 PRS-003 |
| PRS-002 | 平台边界与共享 Core/CLI 设计 | ADR 和路径矩阵通过审阅 | planned | 明确依赖迁移清单 |
| PRS-003 | 创建目标 GitHub repositories | 每个 repo API 读回 | passed | 进入 PRS-004/005：边界化与源码导出 |
| PRS-004 | Core、CLI 与平台边界重构 | 无源仓库相对路径 | planned | 先迁移 shared/runtime 包 |
| PRS-005 | 每个平台/CLI 历史或快照导出 | ref/path/checksum 审计 | in-progress | 导出已完成；转入逐仓独立 CI、权限和交付门验收 |
| PRS-006 | 独立 CI、权限和发布链路 | required checks/Release 通过 | planned | 逐仓迁移 workflows |
| PRS-007 | 生产入口切换和回滚演练 | updater/部署/商店/CLI 入口读回 | planned | 按平台执行 cutover |
| PRS-008 | 源仓库治理-only 收敛 | 无产品构建依赖且可回滚 | planned | 最后执行，需全量证据 |
| PRS-009 | 全目标仓库路由 + Spec-first 门禁 | legacy root `AGENTS.md` 完整路由；所有目标 repo 有 root `AGENTS.md` + Spec policy/template | implemented | 完成全部目标 repo PR/merge/main readback |
