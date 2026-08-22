# CI/CD 运维可观测性与 SLO

## 项目

FAB-P0003 — Fabushi CI/CD & Merge Governance

## 指标来源

`.github/workflows/ci-latency-observability.yml` 通过 GitHub Actions API 读取真实 completed `CI` workflow runs/jobs；不 checkout 产品代码、不绕过 required checks。

## 指标

| 指标 | 定义 |
|---|---|
| workflow duration | GitHub Actions workflow 从 run_started_at 到 updated_at 的墙钟时间 |
| queue delay | created_at 到 run_started_at 的等待时间 |
| validation surface | 实际非 skipped canonical jobs 分类 |
| P50 | 同类验证面中位反馈时间 |
| P95 | 同类验证面尾部反馈时间 |

## SLO budgets

| Surface | P95 budget |
|---|---:|
| fast-path | 30s |
| workflow-governance | 120s |
| single-domain | 900s |
| multi-domain | 1200s |
| full-canonical | 1800s |

少于 5 个样本时状态必须是 `insufficient-samples`；telemetry 是 soft SLO，不能替代安全门禁。

## 2026-08-22 acceptance baseline

Observer run `32564046852` 成功，artifact `9473581875`，SHA-256 digest `00d4fee80b27d4e0d88c3f597b367a9d3b51a88e019b2d093048d39d793395ba`，统计最近 50 个 completed CI runs：

| Surface | N | P50 | P95 | Queue P95 | State |
|---|---:|---:|---:|---:|---|
| fast-path | 32 | 13s | 22s | 0s | within-budget |
| workflow-governance | 4 | 22s | 28s | 0s | insufficient-samples |
| single-domain | 0 | n/a | n/a | n/a | insufficient-samples |
| multi-domain | 0 | n/a | n/a | n/a | insufficient-samples |
| full-canonical | 14 | 104s | 163s | 0s | within-budget |

## Operations

- 先区分 GitHub runner queue delay 与实际 job duration。
- 优先优化 checkout/setup/cache/重复测试，不删除 required safety gates。
- 观测 workflow 失败不授权 CI bypass；按 `runbooks/ci-latency-observation.md` 修复。

## Runtime SLO

N/A: 本项目不拥有应用生产 runtime SLO。Owner: Fabushi maintainers. Revisit trigger: 项目未来开始拥有持久化 release service/runtime。
