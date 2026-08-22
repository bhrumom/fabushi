# 13 CI/CD 与发布

项目文档走 Tier-0/项目类快速验证；触及 Electron/Mahayana/native 时按变更域运行相应 CI。未知运行时路径 fail-safe。

合并只通过受保护 main/merge queue。高风险 capability 先默认关闭/内部启用，再基于 E2E 与遥测扩大。发布证据记录 PR、commit、CI run、artifact/release 与回滚点。
