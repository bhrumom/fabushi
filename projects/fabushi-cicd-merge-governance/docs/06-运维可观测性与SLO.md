# CI/CD 运维可观测性与 SLO

## 项目

FAB-P0003 — Fabushi CI/CD & Merge Governance

## CI 延迟观测目标

FCM-002 建立 CI 反馈时间观测，避免优化只依赖单次运行体验。

## 指标

| 指标 | 定义 |
|---|---|
| workflow duration | GitHub Actions workflow 从开始到完成的墙钟时间 |
| queue delay | workflow queued_at 到 run_started_at 的等待时间 |
| validation surface | 实际运行的 canonical jobs 分类 |
| P50 | 同类变更中位反馈时间 |
| P95 | 同类变更尾部反馈时间 |

## 延迟预算

| Tier | 目标 |
|---|---|
| Tier 0 文档/治理 | 秒级到低几十秒 runner 时间 |
| Tier 1 产品域代码 | 只运行受影响域并并行化 |
| Tier 2 未分类代码 | 安全优先，允许完整验证 |
| Tier 3 敏感发布链路 | 不以速度替代安全 |

## 观测原则

- 指标来源必须是 GitHub Actions 真实运行记录。
- 样本不足时报告样本不足，不生成假趋势。
- 观测 workflow 不成为绕过 required checks 的路径。
- CI 降速时优先定位 checkout、安装、缓存、测试分配和 runner 等因素。

## N/A

生产运行时 SLO 不属于本项目范围；本项目关注工程交付链路可观测性。
