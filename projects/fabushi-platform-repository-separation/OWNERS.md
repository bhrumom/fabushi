# Owners and Review Responsibility

| Role | Owner | Responsibility |
| --- | --- | --- |
| Accountable owner | Repository maintainers | 批准平台边界、目标仓库命名、切换窗口和回滚决定 |
| Execution owner | Active task agent/engineer | 维护路径清单、导出、目标仓库初始化、CI/Release 迁移和证据 |
| Required reviewers | Repository maintainers; platform maintainers | 审查每个仓库的边界、依赖和发布链路 |
| Consulted stakeholders | Web/Desktop/Mobile/Backend/CLI/Marketplace owners | 确认平台源码、资源、密钥和外部发布入口归属 |
| Informed stakeholders | Fabushi contributors and release operators | 在 cutover 前更新 clone、remote 和贡献流程 |

## Escalation

若发现路径同时属于多个平台、目标仓库泄漏了其他平台源码/密钥、平台 CI 无法独立运行、
Release/更新入口失效，或 GitHub 权限不足，立即停止该平台迁移并升级给 repository
maintainers。未完成的平台不阻塞其他独立平台，但不得宣称全量拆分完成。
