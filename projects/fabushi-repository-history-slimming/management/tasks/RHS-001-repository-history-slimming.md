# RHS-001 — Repository history slimming

- Project ID: `FAB-P0010`
- Project Key: `RHS`
- Task ID: `RHS-001`
- Source requirement: `source/2026-09-07-repository-history-slimming.md`
- Status: `passed with immutable-release exception`
- Started: `2026-09-07`
- Updated: `2026-09-09`

## Objective

从最新 GitHub refs 构建隔离的历史重写结果，删除经审核的生成物/缓存/临时历史，保留产品资产和可追溯 ref，并在规则恢复后完成可回滚、可审计的 canonical-main 闭环。由于 GitHub immutable releases 锁定已发布 tags，本任务将“tag 不可改写”作为已验证的外部约束，而不是删除发布物来规避它。

## In scope / out of scope

范围是全量 heads/tags 盘点、路径过滤、完整性审计、保护规则迁移窗口、heads 推送、恢复和证据；tags 只做审计和 OID 保留，不删除 immutable release。范围外是业务代码重构、依赖升级、账号权限变更和本机应用构建/测试。

## Acceptance criteria

1. 项目记录先通过项目治理检查并合入 canonical `main`。
2. 推送前后远端 heads 名称集合按批准的 544 个过期 head 清理收敛；401 个 immutable-release tags 保持原 OID；OID 映射和原始回滚清单齐全。
3. 审核生成路径在候选新历史中无残留，关键产品路径差异已审计；post-main CI 已验证接受的瘦身产品树。
4. 候选 `git fsck --full`、连通性和 GitHub 新 `main`/heads 读回通过。
5. 规则只在迁移窗口改变，完成后恢复；页面显示 `Bypass list is empty`。
6. 本机不运行构建、打包、原生测试或 E2E。

## Open-source survey and decision

- [`newren/git-filter-repo`](https://github.com/newren/git-filter-repo)：Git 项目推荐的历史重写工具，支持全 refs、路径过滤、回调和可审计的精确规则；采用其官方实现，不复制代码。其仓库同时提供 MIT/GPL 许可文件，实际使用遵循工具发布许可。
- [`rtyley/bfg-repo-cleaner`](https://github.com/rtyley/bfg-repo-cleaner)：成熟且快速，适合按 blob 大小或简单模式清理；本任务需要多组目录族、全部 refs 和产品保留审计，BFG 的简化模型不如 filter-repo 可控，故不作为主工具。其仓库为 GPL-3.0，未引入。
- [`github/git-sizer`](https://github.com/github/git-sizer)：只读计算可达对象和体积指标；借鉴其指标模型用于前后审计，不把工具或代码加入产品。

结论：使用隔离 bare 镜像 + git-filter-repo 执行重写，使用 Git 原生命令和 git-sizer 思路做审计；不做本地构建验证。

## Branch / commit / PR

- Project bootstrap branch: `codex/rhs-project-bootstrap-20260907`
- Project bootstrap PR: [#2482](https://github.com/bhrumom/fabushi/pull/2482), merged into canonical main at `7f31e97787c7c669a005b08245b72c03b07f306f`
- History rewrite: direct canonical ref migration from isolated candidate; rewritten `main` is `bc4fb3032a03d6600d733ce28295256d77cca9d4`; no normal PR can represent a force-updated history.
- Final record branch: `codex/rhs-finalize-20260907` (this documentation round)
- Final record PR: [#2483](https://github.com/bhrumom/fabushi/pull/2483), merged at `6afd3475744d284d797140a2393d3a3fc551c211`.
- Canonical-main readback on 2026-09-09: `7ea5055b1e0d7ee078d0d21321b5884fa93bead2`; it contains the accepted rewritten product SHA `bc4fb3032a03d6600d733ce28295256d77cca9d4`.

## Verification and evidence

已产生的证据：

- 原始 refs 清单：`/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/refs-before-7f31e977.txt`，SHA-256 `939f903334e216be9c3ba173e65cc7870a4d5c11fbae66606454374211deeecd`。
- 原始 remote bare 镜像：`/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/remote-source-before-rewrite.git`，`git fsck --full` 通过。
- 材料归档：`/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/materials-7f31e977.tar.gz`，133 MiB，SHA-256 `a743786000d237b62c101a4edc0f526d0c5238ed6e5bc7643fad1c24ce88e667`。
- 候选 self-contained bare 镜像：`candidate-slim`；pack 717,939 KiB，75,238 objects，garbage 为 0，`git fsck --full` 通过。
- 当前树审计：13,678 files / 1,104,229,976 bytes → 10,894 files / 455,418,012 bytes，减少 2,784 files、648,811,964 bytes（约 58.7%）。
- 远端迁移时读回：`main=bc4fb3032a03d6600d733ce28295256d77cca9d4`，1572 heads，401 tags；2026-09-09 当前读回为 `main=7ea5055b1e0d7ee078d0d21321b5884fa93bead2`，1598 heads，419 tags。
- [`Electron desktop quality gate`](https://github.com/bhrumom/fabushi/actions/runs/34085259212)：首次 macOS 用户旅程失败，保留失败诊断；重跑 attempt 2 成功，macOS job [101639923085](https://github.com/bhrumom/fabushi/actions/runs/34085259212/job/101639923085)，Linux/Windows 与汇总任务也成功。成功产物包括 Electron macOS 包和用户旅程诊断；失败与成功诊断均保留在该 run 的 artifacts 中。
- [`Native mobile quality gate`](https://github.com/bhrumom/fabushi/actions/runs/34085259258)：成功，Android instrumentation 报告和 iOS xcresult 已保留。

Post-main product delivery：`passed`，针对接受的瘦身产品 SHA `bc4fb3032a03d6600d733ce28295256d77cca9d4`。Electron macOS/Linux/Windows 打包、签名、公证及完整用户旅程均由 GitHub Actions 重跑通过；Native mobile quality gate 也通过。本机未执行构建、打包、原生测试或 E2E。

## Blockers / risks

主要风险为 force push、路径误删、漏 ref 和 immutable release 限制；前述风险已通过归档、隔离镜像、读回审计和 post-main 质量门缓解。下一动作：无；若未来需要改写 immutable tags，必须另行评估 release 保留与仓库迁移方案。
