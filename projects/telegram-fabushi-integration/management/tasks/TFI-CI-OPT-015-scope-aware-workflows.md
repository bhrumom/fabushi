# TFI-CI-OPT-015 — 按变更范围选择自动化检查

- portfolio project_id: FAB-P0001
- project_key: TFI
- task_id: TFI-CI-OPT-015
- status: IN_PROGRESS
- started: 2026-09-14 Asia/Shanghai
- updated: 2026-09-14 Asia/Shanghai
- owner: Fabushi CI/release engineering
- source: projects/telegram-fabushi-integration/source/2026-09-14-ci-scope-aware-automation.md
- dependency: product baseline main@27a9112325f8506fecf5060ebdf0a6d9d986f2d2

## 目标

让自动化工作流先识别当前 PR、merge queue 或 main push 实际触及的产品边界，再只启动受影响的检查。未受影响的 job 保留稳定的 skipped/success 结果，并由现有聚合检查接受 success 或 skipped，避免绕过保护主线或让 Merge Queue 等待不存在的状态。

## 范围

- Computer control security gate：保留 Chrome/Node 相关检查；Chrome-only 变更跳过 Rust contracts、platform-worker 与 Linux managed desktop。
- Electron desktop quality gate：Chrome-only 变更跳过 Linux Electron PR 旅程；main push 的完整三平台打包与 post-main 交付不变。
- GBF security closure：只有 GBF/共享安全边界变更才运行闭环；Chrome-only 变更跳过。
- Global Dharma Web Service Contract：只在 backend、Web Mini App 或 commerce contract 相关路径变更时运行对应 job；项目治理文档变更不安装这些依赖。
- 使用固定提交的成熟路径过滤动作；scope 配置或 workflow 变更采用保守全量策略。
- 更新项目 WBS、验收、状态、变更、风险/行动、质量及发布记录。

非范围：删除现有安全检查、降低 Rust/依赖审计/打包/主线发布门禁、修改业务运行时、改变 Chrome Web Store 发布策略、在本地执行重型构建或测试。

## 依赖

- main@27a9112325f8506fecf5060ebdf0a6d9d986f2d2 已包含本轮用户脚本/Chrome 宿主修复和本需求源记录。
- GitHub protected main / merge queue 的稳定 check name 不得消失。
- 需要通过 GitHub Actions 验证 workflow YAML、scope 输出、skipped 聚合和 main push 全量路径。

## 验收标准

- [ ] 每个受治理 workflow 有轻量 scope job，输出可审计的 global/backend/web/commerce/gbf/node/rust/platform-worker/electron 等范围。
- [ ] PR 与 merge_group 按 changed paths 选择 job；push main 与 workflow_dispatch 保持完整验证/交付。
- [ ] Chrome-only 变更不启动 Computer Control Rust 三 OS、platform-worker、Linux managed desktop、Electron Linux PR journey、GBF closure 与无关 Global Dharma job；Chrome package/相关 Node 检查仍运行。
- [ ] 纯项目治理文档变更不启动 Global Dharma backend/web/commerce 依赖安装。
- [ ] scope/action/config/workflow/安全边界变化触发保守全量路径。
- [ ] skipped job 及结果聚合均返回可接受的成功状态，Merge Queue 不因缺少 required context 阻塞。
- [ ] GitHub Actions 保留 scope 输出、各 job 结果和缓存/耗时摘要；不在本地运行应用构建、原生测试或 E2E。
- [ ] 实际 Actions 运行证明至少一个 Chrome-only/非目标变更跳过无关重作业，并记录 run/job URLs；main 合并后 canonical readback 完整。

## 开源优先调查与决策

已调查：

- dorny/paths-filter (https://github.com/dorny/paths-filter)：MIT；成熟的 changed-path filter，支持 pull_request、push、merge_group、inline filters、排除规则、boolean outputs 和 changes 输出。v4 固定提交为 ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d。
- tj-actions/changed-files (https://github.com/tj-actions/changed-files)：MIT；支持 merge queue、矩阵和丰富 changed-file 输出，固定候选为 v47 提交 24d32ffd492484c1d75e0c0b894501ddb9d30d62。
- actions/github-script (https://github.com/actions/github-script)：MIT；可自定义 GitHub API 脚本，但会引入自维护 diff/规则代码。

决策：采用 dorny/paths-filter v4 的固定 commit 和 inline filter。它已经覆盖本任务所需的 PR/merge_group/base/ref/排除语义，减少自定义 diff 解析和 token 权限面；不复制第三方代码、不新增运行时依赖。tj-actions 保留为拒绝候选，因为本轮不需要逐文件列表/动态矩阵；github-script 保留为拒绝候选，因为自定义 API 逻辑会增加维护和权限复杂度。

## 验证方法

- 轻量本地检查：只读 workflow、项目记录和 diff；不运行构建、Cargo/npm 安装、应用测试或 E2E。
- GitHub Actions：workflow syntax/各受影响 job、scope 输出、skipped 结果、protected PR checks、merge_group/main push。
- 交付证据：记录 exact main SHA、run/job/check URL、scope 输出与跳过矩阵；如 workflow 改动触发产品包交付，按项目 post-main gate 记录 packaged/E2E/release evidence。

## 分支 / PR / 实现状态

- branch: codex/tfi-ci-scope-aware-015-20260914
- PR: pending implementation
- implementation: task record created; workflow changes pending
- status: IN_PROGRESS

## 风险与下一动作

- 风险：过滤规则过窄会漏掉真实影响，过宽会继续浪费矩阵；对 workflow、scope、脚本、全局工具链和安全边界采用保守全量，并以 Actions 实际 run 验证。
- 风险：merge_group 的 changed-base 语义必须由 GitHub Actions 回读确认；scope job 使用完整 checkout 和空 token 的 git diff 路径。
- 下一动作：更新四个 workflow，增加 scope job、受控 job if 和 skipped-tolerant result；提交 PR 后先验证保守全量，再用后续非目标变更 run 验证跳过效果。


## 2026-09-14 — Chrome-only scope proof follow-up

- proof branch: codex/tfi-ci-scope-proof-chrome-only-20260914
- test change: chatgpt-vps-control/chrome-platform/README.md plus this task record; no Rust, Worker, Electron, GBF, backend, Web Mini App or commerce source changed.
- expected selection: Chrome package and Computer Control Node security remain relevant; Computer Control Rust/platform-worker/Linux desktop, Electron platform, GBF closure and Global Dharma backend/web/commerce are skipped while their workflow/scope/result contexts remain present.
- status: awaiting Actions scope/skipped evidence.


## 2026-09-14 — Chrome-only scope proof r2

- base main: e525adb298066ab4e234cacca51525f921bb6736 (policy plus stable Electron skipped-name fallback).
- fixture: documentation-only change under chatgpt-vps-control/chrome-platform/.
- expected result: Electron Linux must remain a named skipped check; Computer Control Rust/platform-worker/Linux desktop, GBF closure and Global Dharma service jobs must remain skipped; Chrome package and Node security remain selected.
- status: awaiting final Actions readback.


## 2026-09-14 — Chrome-only scope proof final

- proof branch: codex/tfi-ci-scope-proof-chrome-only-final-20260914
- only changed boundary: chatgpt-vps-control/chrome-platform/README.md.
- expected final Actions evidence: Chrome package and Node security selected; Rust contracts, platform-worker, Linux managed desktop, Electron platform, GBF closure, and Global Dharma service jobs skipped; Electron desktop result remains successful.
- status: awaiting final Actions readback and protected merge.
