# Fabushi CI/CD & Merge Governance

- **Project ID:** `FAB-P0003`
- **Project Key:** `FCM`
- **Repository:** `bhrumom/fabushi`
- **Canonical path:** `projects/fabushi-cicd-merge-governance/`

## Objective

把 Fabushi 的 CI/CD、合并与发布链路建设为高吞吐、低等待、可审计且 fail-safe 的工程体系：低风险变更只跑必要验证；所有主干合并保留 required check + merge queue；生产/商店发布只接受与目标平台一致、来自受保护主干且已有质量证据的 exact source SHA。

## Current verified status

`active` — G0 fast-safe merge 已完成；G1 latency observability、G2 release-source safety、G3 ownership automation 正在 PR #1999 做最终实现与 protected-main 验收。任何这些任务在 CI/merge queue/main verification 之前都不能标记完成。

## Current stage / next gate

`g1-g3-implementation-and-closure`

Next gate: PR #1999 dedicated governance/latency workflows + canonical `CI result` green, then protected merge queue, then canonical `main` verification and final closure-record PR.

## Scope

- change-aware canonical CI and aggregate `CI result`;
- merge-group exact-diff classification and protected merge queue;
- queue-aware automerge authorization;
- change-aware Worker/Fabushi Pay CD;
- CI latency P50/P95 + queue-delay observability;
- exact-SHA Apple/Google release-source gating;
- narrow sensitive-path CODEOWNERS and governance contract;
- project/evidence/runbook closure.

## Non-goals

- bypassing required checks or branch protection to improve latency;
- moving heavy builds/tests to the local development machine;
- storing signing secrets or store credentials in project records;
- automatically submitting App Store/Play review without the explicit product release workflow.

## Source of truth

1. `projects/PORTFOLIO.json` for immutable Project ID;
2. `SOURCE_OF_TRUTH.md` and `source/` for requirements;
3. accepted ADRs/specs/WBS/acceptance records;
4. live GitHub PR/CI/merge/release facts for implementation state.

## Owners

See `OWNERS.md`. Sensitive governance/release paths are assigned to `@bhrum` via `.github/CODEOWNERS` without a repository-wide catch-all.

## Acceptance summary

Project completion requires all required WBS tasks passed, dedicated latency/delivery-governance checks successful, PR/merge-group `CI result` successful, merge through protected queue, canonical `main` verification, and synchronized task/WBS/milestone/acceptance/status/changelog/evidence records.

## Navigation

- `SOURCE_OF_TRUTH.md`
- `OWNERS.md`
- `docs/02-需求与成功指标.md`
- `docs/03-架构与实现策略.md`
- `docs/04-质量与测试策略.md`
- `docs/05-发布迁移与回滚.md`
- `docs/06-运维可观测性与SLO.md`
- `docs/07-安全隐私与合规.md`
- `docs/19-完成定义与验收.md`
- `management/00-路线图.md`
- `management/01-WBS原子任务.md`
- `management/02-里程碑.md`
- `management/03-验收追踪矩阵.md`
- `management/05-状态报告.md`
- `management/tasks/`
- `decisions/`
- `evidence/`
- `runbooks/`
