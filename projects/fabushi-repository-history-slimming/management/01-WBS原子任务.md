# WBS 原子任务

| ID | 原子任务 | 状态 |
| --- | --- | --- |
| RHS-001 | 历史瘦身端到端迁移 | passed with immutable-release exception |
| RHS-002 | 注册项目并合入 canonical `main` | passed |
| RHS-003 | 最新远端 refs 与保护规则基线 | passed |
| RHS-004 | 隔离重写、路径保留和完整性审计 | passed |
| RHS-005 | 受保护 refs 迁移窗口、推送与规则恢复 | passed with exception（immutable tags/refs/pull 不可改写） |
| RHS-006 | canonical-main 读回与证据闭环 | passed（Electron 与 Native mobile quality gates） |
