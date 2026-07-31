# 大乘小程序混合市场与可信发布任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 4`  
文档状态：等待产品审核，尚未合并到 `main`，不得启动实施 Action。

## 一句话目标

把现有“提交一个部署 URL 并校验固定安装包”的市场升级为：

> 一个插件一个稳定身份和独立 Cloudflare 逻辑服务；一个版本一个不可变发布物；大乘市场负责身份、发现、审核和信任；大乘 CLI 直连插件服务下载并完成签名、哈希、权限、来源和防回退校验；插件 MCP 默认采用 MCP `2026-07-28` 无状态协议和标准 MCP Apps，在 Cloudflare 全球边缘节点运行。

普通发布者默认只需使用大乘账号和 CLI，不需要配置 Cloudflare API Token、Worker 名称、Pages 项目或 D1；平台在后台完成构建、隔离部署、签名、审核和发布。高级发布者可以选择自托管，但必须证明部署所有权并遵守同一不可变发布与信任契约。

## 必读顺序

1. `PRD.md`：产品目标、用户、范围、功能需求和非目标。
2. `TECHNICAL_DESIGN.md`：目标架构、组件边界、部署模型、下载和安装链路。
3. `MCP_2026_07_28_EDGE.md`：MCP 最新无状态协议、MCP Apps、Tasks、MRTR、边缘部署和兼容迁移设计。
4. `MCP_2026_07_28_REFERENCES.md`：MCP 和 Cloudflare 的官方发布、SDK 与迁移资料。
5. `API_CONTRACT.md`：市场、发布、审核、下载、回滚和撤销 API 契约。
6. `DATA_MODEL.md`：发布者、插件、版本、部署、权限、签名和审计数据模型。
7. `SECURITY_MODEL.md`：威胁模型、OIDC、签名、provenance、权限和 TUF 思想。
8. `PUBLISHING_WORKFLOW.md`：托管模式、自托管模式和 CLI 发布体验。
9. `UI_UX.md`：CLI、桌面/移动市场和发布者界面的交互要求。
10. `MIGRATION_PLAN.md`：从当前 v1 市场迁移到目标架构的兼容步骤。
11. `ACCEPTANCE.md`：强制验收矩阵和真实端到端证据。
12. `REFERENCES.md`：市场、发布和更新安全的行业与官方资料。

所有文档共同构成实施约束；其中 `MCP_2026_07_28_EDGE.md` 的协议和边缘迁移要求为强制项，不能以“市场功能已完成”为由跳过。

## 已确认的当前基础

当前仓库不是从零开始，已经具备以下基础能力：

- 动态市场发布者认证和插件 ID 占用检查；
- 同一插件版本不可重复发布；
- 发布时从独立 HTTPS 部署读取安装包；
- 校验声明大小、gzip 格式和 SHA-256；
- 非管理员发布进入待审核，管理员发布可直接批准；
- 市场浏览返回插件版本、大小、哈希和部署地址；
- 下载接口使用 307 跳转到插件自己的部署地址；
- CLI/桌面端已有官方插件发现、安装和本地插件目录；
- Web 小程序已有 MCP tools/resources 和 iframe UI 桥接雏形。

主要缺口是：

- 安装包地址仍固定为可覆盖的 `/mahayana/plugin.tar.gz`；
- 插件身份尚未完整命名空间化；
- 缺少平台托管发布、OIDC 短期凭证、签名元数据、来源证明、权限差异确认、撤销、回滚、防回退、审核等级和完整审计；
- 小程序宿主仍固定使用 `mcp-2025-06-18`、`initialize`、`Mcp-Session-Id` 和长期 GET/SSE；
- 边缘 MCP 服务尚未全面采用 MCP `2026-07-28` 无状态协议；
- 小程序 UI 尚未完整采用官方 MCP Apps AppBridge、`ui://`、CSP 和能力协商；
- 长时间发布、部署和扫描尚未统一映射到 MCP Tasks。

## 不可改变的架构决策

- 一个插件是独立的逻辑部署单元，不是一台独立虚拟机。
- 一个插件对应一个稳定 Cloudflare Worker/Pages 项目或服务边界。
- 一个版本对应该服务的一次不可变版本和不可变发布物。
- 不为每个版本永久创建一个新的 Worker 服务名称。
- 禁止 R2 承载插件安装包或插件静态资源。
- 市场控制平面不永久代理所有下载字节。
- 不允许第三方插件共享写权限、Secret、数据库或部署凭证。
- 普通发布者默认不接触 Cloudflare 长期凭证。
- 已发布的插件 ID 与版本组合不可覆盖复用。
- 旧版本必须能在保留期内用于回滚和审计。
- 新插件 MCP 服务默认采用 MCP `2026-07-28` 无状态路径。
- MCP transport session 不能被重新包装成 Durable Object 或共享 session store。
- 业务状态必须使用显式 ID、task handle、resource URI 或授权主体表达。
- 新小程序 UI 使用标准 MCP Apps；不支持 MCP Apps 的宿主必须有文本降级。
- 旧协议仅作为迁移期兼容通道，不能继续作为新插件模板默认值。

## 实施边界

本任务要求代码、数据库迁移、CLI、市场 API、Cloudflare 发布流程、MCP 宿主、无状态 MCP 服务、MCP Apps、Tasks、MRTR、权限和安全校验、真实示例插件及 GitHub Actions 验证全部落地。

只更新文档、只增加 mock、只升级依赖、只替换协议版本字符串、只验证本地夹具、只验证官方内置插件或只完成 SHA-256 校验均不算完成。

## 文档更新规则

任务目标或任一强制设计发生实质变化时，同时更新：

- 本目录中的相应文档；
- `actions-inbox.json` 中的 `prompt`；
- 该任务的 `goalVersion`；
- 顶层 `revision`。

动态控制器会在当前 Chat 完成本轮后、创建下一轮新 Chat 之前读取更新，不会中断正在运行的 Chat。
