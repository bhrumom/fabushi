# Evidence

本目录保存 PRS 拆仓的可重建证据索引，不保存 secrets、cookie、签名材料或大体积构建缓存。

每个证据条目应至少绑定：`FAB-P0013`、Task ID、源 canonical SHA、目标仓库、目标 SHA、GitHub
workflow run/job、平台、时间、artifact 名称和校验值。

建议索引：

- `PRS-001/`：项目注册、portfolio validator、canonical-main readback。
- `PRS-003/`：目标仓库创建、默认分支、可见性和 branch protection readback。
- `PRS-005/`：源/目标 refs、路径 manifest、tree/object checksum。
- `PRS-006/`：独立 CI、打包、E2E、CLI checksum 和 Release 证据。
- `PRS-007/`：入口切换、部署、商店/updater 和回滚演练。

当前 M3 导出汇总：`PRS-005-platform-export-20260918.md`。该索引绑定 13 个目标仓库的正式
workflow run、源/目标 SHA、路径数量、artifact 和 bootstrap 回滚引用；独立 CI、发布和生产切换
仍由后续任务维护。
