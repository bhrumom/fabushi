# 大乘 CLI 云端插件市场任务文档

本目录是任务 `mahayana-marketplace-cloudflare-20260730` 的唯一任务文档目录。

执行该任务的 Chat 必须先阅读本目录下与任务有关的全部文档，再开始实现和验收。任务消息只提供本目录的仓库路径与 GitHub 文件夹链接，不复制文档正文。

当前文档：

- `PRD.md`：产品目标、范围和约束。
- `TECHNICAL_DESIGN.md`：架构、安装链路和安全要求。
- `UI_UX.md`：市场浏览、安装和运行交互要求。
- `ACCEPTANCE.md`：端到端验收标准和证据要求。

任务目标或文档发生实质变化时，应同时更新 `actions-inbox.json` 中该任务的 `goalVersion` 和顶层 `revision`，使运行中的 Action 在下一次轮询时派发新版本任务。
