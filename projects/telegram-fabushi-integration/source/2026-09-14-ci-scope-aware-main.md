# 2026-09-14 用户追加要求：main 也必须按变更范围运行 CI

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-CI-OPT-015`
- 来源：用户在 2026-09-14 追加明确要求：“你为什么还跑那么多无关的东西？Main也一样。无关的CI不要跑。”

## 需求解释

之前的 scope 只在 PR/merge_group 的重 job 条件中生效，main push 仍使用 `github.event_name == 'push'` 直接放行，因此即使 main 上只有 Chrome/userscript、项目文档或其他单一边界变更，也会启动 Rust 多平台、Electron、Native mobile 等无关矩阵。本追加需求把同一套 changed-path 选择应用到 main push。

## 目标行为

- `pull_request`、`merge_group` 和 `push(main)` 都先做范围检测，再只启动受影响 job。
- `workflow_dispatch` 是显式人工全量入口，保留全量验证能力。
- Chrome-only main 变更继续运行 Chrome 包/旅程及必要的 Node 检查，但跳过 Rust contracts、platform-worker、Linux managed desktop、Electron package、GBF closure、Native mobile 和 Global Dharma 服务依赖。
- Electron、Native Android/iOS、GBF、Global Dharma backend/Web/commerce 各自只由自己的输入边界触发。
- 发布/下游 workflow_run 只能在上游确实产生了对应产品构建结果时进入，不得因为一个被 scope 跳过的工作流而等待不存在的 artifact/check。
- 未选中的 job 仍保留稳定的 `skipped` / 聚合 `success` 结果；不通过删除 required check 来“优化”。

## 设计约束

- 保持 dorny/paths-filter v4 的固定 commit 和现有 scope 输出，main push 使用 `github.event.before` 比较上一个 main commit。
- 收窄各 workflow 的 main push 顶层 paths，避免无关 main commit 甚至创建重 workflow_run；PR/merge_group 的 scope/result 稳定性继续保留。
- 共享 CI 控制文件只在确实属于对应边界时触发对应 workflow；不再把所有 `.github/workflows/**` 当成所有产品矩阵的全局变更。
- 不在本地运行构建、Cargo/npm 重型测试或 E2E；用 GitHub Actions 验证 main 的实际 skipped/selected 结果。

## 2026-09-15 — CI-only contract fixture boundary

The native direct-platform-gates contract is a CI control-plane test, not Electron, GBF, Chrome-product, or Linux-desktop implementation. Product workflow path filters therefore exclude `chatgpt-vps-control/tests/native-direct-platform-gates-contract.test.js` from those product scopes, while the shared Computer Control Node security scope remains eligible for JavaScript checks. This keeps a change to the contract test from creating unrelated product workflows.
