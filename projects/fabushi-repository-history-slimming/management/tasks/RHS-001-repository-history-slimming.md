# RHS-001 — Repository history slimming

- Project ID: `FAB-P0010`
- Project Key: `RHS`
- Task ID: `RHS-001`
- Source requirement: `source/2026-09-07-repository-history-slimming.md`
- Status: `in-progress`
- Started: `2026-09-07`
- Updated: `2026-09-07`

## Objective

从最新 GitHub refs 构建隔离的历史重写结果，删除经审核的生成物/缓存/临时历史，保留产品资产和 ref 名称，并在规则恢复后完成可回滚、可审计的 canonical-main 闭环。

## In scope / out of scope

范围是全量 heads/tags、路径过滤、完整性审计、保护规则迁移窗口、推送、恢复和证据。范围外是业务代码重构、依赖升级、账号权限变更和本机应用构建/测试。

## Acceptance criteria

1. 项目记录先通过项目治理检查并合入 canonical `main`。
2. 推送前后所有远端 head/tag 名称集合一致，OID 映射和原始回滚清单齐全。
3. 审核生成路径在新历史中无残留，关键产品路径无意外删除。
4. `git fsck --full`、连通性和 GitHub 读回通过。
5. 规则只在迁移窗口改变，完成后恢复到迁移前快照。
6. 本机不运行构建、打包、原生测试或 E2E。

## Open-source survey and decision

- [`newren/git-filter-repo`](https://github.com/newren/git-filter-repo)：Git 项目推荐的历史重写工具，支持全 refs、路径过滤、回调和可审计的精确规则；采用其官方实现，不复制代码。其仓库同时提供 MIT/GPL 许可文件，实际使用遵循工具发布许可。
- [`rtyley/bfg-repo-cleaner`](https://github.com/rtyley/bfg-repo-cleaner)：成熟且快速，适合按 blob 大小或简单模式清理；本任务需要多组目录族、全部 refs 和产品保留审计，BFG 的简化模型不如 filter-repo 可控，故不作为主工具。其仓库为 GPL-3.0，未引入。
- [`github/git-sizer`](https://github.com/github/git-sizer)：只读计算可达对象和体积指标；借鉴其指标模型用于前后审计，不把工具或代码加入产品。

结论：使用隔离 bare 镜像 + git-filter-repo 执行重写，使用 Git 原生命令和 git-sizer 思路做审计；不做本地构建验证。

## Branch / commit / PR

- Project bootstrap branch: pending
- Project bootstrap PR: pending
- History rewrite branch/commit: pending, to be created only after latest canonical-main readback

## Verification and evidence

当前仅有项目启动和工具调研证据；重写、fsck、refs 对照、规则恢复、GitHub Actions 与 canonical-main 证据待后续阶段产生。Post-main product delivery：N/A，原因是目标只改变 Git 历史、治理记录和忽略规则，不改变应用运行时；若验证发现产品构建输入受影响，立即转为 CI packaged E2E gate。

## Blockers / risks

主要风险为 force push、路径误删、漏 ref 和保护规则恢复失败；缓解措施见 `management/04-风险登记.md`。当前下一动作是提交项目登记 PR，而不是直接改远端历史。
