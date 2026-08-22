# 运维可观测性与 SLO

## Runtime applicability

本治理项目不直接承载用户流量，因此传统服务 uptime/latency SLO 不适用。

## Governance SLOs

| SLI | Target |
|---|---|
| 新 repository task 在实质工作前可定位到 Project ID/项目目录 | 100% |
| `passed` task 具备 objective evidence | 100% |
| 新 enterprise project mandatory files 完整或显式 N/A | 100% |
| AGENTS/Skill/CI/governance meta tasks 具有项目任务记录 | 100% |
| 变更后 canonical `main` 验证 | 100% required completed tasks |

## Observability

- GitHub project folder: durable status/evidence history.
- GitHub PR/CI: merge and acceptance telemetry.
- Task Orchestration/Sheets when used: portfolio/control view, linked to stable IDs.
- `management/05-状态报告.md`: append-only execution rounds.
- `management/04-风险登记.md` and `06-依赖与阻塞.md`: governance health signals.

## Alerts / triggers

Treat the following as governance incidents requiring follow-up:

- work begins without a project/task record;
- task is reported complete while CI/merge/release evidence is pending;
- duplicate project folders are created for the same objective;
- external mirror overwrites canonical project state;
- secrets/private data appear in project records;
- root AGENTS, Skill, and project standard drift materially.

## Runbook

See `runbooks/README.md` for standard governance recovery/audit procedures.
