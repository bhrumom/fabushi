# 大乘 GitHub 原生共创、多构件 MCP Apps 任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 9`  
文档状态：已完成产品审核，批准全面实施与验收。

## 一句话目标

> 每个大乘小程序既是可安装的标准 MCP App，也是可 Fork、可由 AI 修改、可提 Pull Request、可独立派生发布的 GitHub 仓库；源码共创开放，正式插件身份和发布供应链受保护。

## 最高优先级设计

1. `GITHUB_NATIVE_MCP_APP_COLLABORATION.md`：GitHub 仓库、Fork、PR、AI 修复、派生发布和供应链安全；
2. `MULTI_ARTIFACT_MCP_APP.md`：一个插件身份和版本包含 common、native CLI、web-wasm 等按平台选择的构件；
3. `LOCAL_WEB_MCP_RUNTIME.md`：移动端/Web 下载本地网页和 WASM 包运行；
4. `LOCAL_FIRST_MCP_APPS.md`：本地优先执行；
5. `MCP_APPS_ONLY.md`：MCP Apps UI、Host、安全和旧协议删除。

所有市场发布、父级 Release Manifest、构件 provenance、SBOM 与 attestations 必须绑定同一精确 source commit。

## GitHub 共创原则

- 市场版本绑定稳定 GitHub repository ID、精确 commit、tree hash 和 SPDX license；
- 用户可以报告 Issue、Fork、让 AI 修复并创建 Draft PR；
- AI 只能在用户 Fork 或授权分支修改，不能直接推送上游受保护分支；
- Fork PR 只运行 `pull_request` 无 Secret、只读 Token、隔离环境 CI；
- 禁止在有 Secret/写权限的 `pull_request_target` 中 checkout 或执行 Fork 代码；
- PR 合并不等于发布；只有上游受保护分支、受保护标签和可信 Release workflow 能发布正式版本；
- 正式发布使用 OIDC、SBOM、artifact attestations、provenance、source commit 绑定和市场签名；
- Fork 可贡献回上游，也可更换 plugin ID 后发布自己的派生 App；
- 派生 App 必须展示上游来源、许可证、差异、权限变化和同步状态，不能复用上游官方身份或签名。

## 多构件运行原则

同一个全球法布施 Release 包含：

- `common`：MCP Apps UI、Tools、权限、Skills 和工作流；
- `native-*`：macOS、Windows、Linux 的本地 CLI；
- `web-wasm`：iOS、Android、桌面 WebView 和普通 Web/PWA 的本地网页/WASM Runtime。

平台安装器只下载当前平台需要的最小构件，但所有构件共享同一插件 ID、版本和 Tool Contract。

## 审核状态

本任务方案已经产品审核通过，自 `goalVersion = 9` 起进入全面实施与验收：

- 按受保护分支、Pull Request、CODEOWNERS 和 ruleset 流程推进实现与合并；
- 启动并持续执行所需 GitHub Actions、真实发布和跨平台验收；
- 所有正式 Release 继续遵守可信工作流、OIDC、SBOM、artifact attestations、provenance 和人工/环境审批；
- 只有全部强制验收项均取得可复核真实证据后，任务状态才可报告为完成。
