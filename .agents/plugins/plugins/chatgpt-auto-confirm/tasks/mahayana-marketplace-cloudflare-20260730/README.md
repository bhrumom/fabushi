# 大乘 GitHub 原生共创、多构件 MCP Apps 任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 11`  
文档状态：已完成产品审核，批准全面实施与验收。

## 一句话目标

> 用户生成小程序时源码先在本地持久化并可本地运行；只有用户明确“上线”后才创建远程仓库。未连接 GitHub 的登录用户可一键托管到 `bhrumom` 官方组织仓库；主动选择 GitHub 官方连接器的用户可部署到自己的 GitHub。上线后继续使用 GitHub 原生共创、可信 Release、多构件分发和本地运行架构。

## 最高优先级设计

1. `LOCAL_GENERATION_GITHUB_DEPLOYMENT.md`：本地先生成、官方 `bhrumom` 托管、用户 GitHub 双部署出口和部署 API；
2. `GITHUB_NATIVE_MCP_APP_COLLABORATION.md`：GitHub 仓库、Fork、PR、AI 修复、派生发布和供应链安全；
3. `MULTI_ARTIFACT_MCP_APP.md`：一个插件身份和版本包含 common、native CLI、web-wasm 等按平台选择的构件；
4. `LOCAL_WEB_MCP_RUNTIME.md`：移动端/Web 下载本地网页和 WASM 包运行；
5. `LOCAL_FIRST_MCP_APPS.md`：本地优先执行；
6. `MCP_APPS_ONLY.md`：MCP Apps UI、Host、安全和旧协议删除。

所有旧文档若与上述文件冲突，以该顺序为准。所有市场发布、父级 Release Manifest、构件 provenance、SBOM 与 attestations 必须绑定同一精确 source commit。

## 用户生成与上线原则

- 用户在联系人/机器人聊天中让 AI 生成代码时，源码首先写入设备本地工作区；
- 生成、修改、本地运行不得依赖 GitHub 登录或网络；
- 没有用户明确“上线”动作，不得静默创建远程仓库或上传源码；
- 用户只登录法布施账号即可选择“法布施官方托管”，由可信后端使用官方 GitHub App/组织安装权限在 `bhrumom` 创建独立规范化仓库；
- 用户在聊天框“+”中选择 GitHub 官方连接器并明确“部署到我的 GitHub”时，才使用用户 GitHub 授权身份创建/更新其个人或授权组织仓库；
- 用户 GitHub access token、refresh token、connector secret 不得复制或长期保存到法布施后端；
- 上线失败不影响本地工作区；用户可继续本地运行、修改或切换另一部署目标；
- 源码首次推送成功不等于公开发布，也不等于自动进入市场；正式版本仍需可信 GitHub Release 流程。

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

## goalVersion 11 强制验收

除既有 GitHub 原生协作与多构件验收外，必须真实证明：

1. 新用户完全不连接 GitHub，仅登录法布施账号，也能通过聊天生成真实小程序；
2. 代码先真实写入本地工作区，断网仍可打开、修改和本地运行；
3. 点击“官方托管上线”后，无 GitHub 账号也能在 `bhrumom` 下创建真实独立仓库并写入首个 commit；
4. 官方托管仓库的文件/hash 与本地发布快照一致且不含 Secret、聊天记录、缓存或本地数据库；
5. 同一能力通过 GitHub 官方连接器部署到测试用户自己的 GitHub 仓库；
6. 用户 GitHub 凭证不出现在法布施 API、数据库、日志、Actions artifact 或仓库；
7. 两种部署路径都能继续走真实 Actions、受保护 Release、SBOM、attestation、市场登记和客户端本地运行；
8. 已上线项目再次修改时不会强推覆盖远程未知提交，分叉时必须 fetch/compare/merge 或 rebase；
9. GitHub 连接器断开不影响本地项目和已存在的官方托管项目。

## 审核状态

本任务方案已经产品审核通过，自 `goalVersion = 11` 起按上述模型全面实施与验收：

- 按受保护分支、Pull Request、CODEOWNERS 和 ruleset 流程推进实现与合并；
- 启动并持续执行所需 GitHub Actions、真实发布和跨平台验收；
- 所有正式 Release 继续遵守可信工作流、OIDC、SBOM、artifact attestations、provenance 和人工/环境审批；
- 只有全部强制验收项均取得可复核真实证据后，任务状态才可报告为完成。
