# PRD：大乘 MCP Apps 小程序市场与可信发布

## 1. 产品目标

大乘小程序统一升级为官方 MCP Apps。小程序不再分为“大乘自定义 iframe 小程序”和“标准 MCP 插件”，而是统一为：

```text
MCP SDK v2 Server
+ MCP Apps ui:// resources
+ AppBridge Host
+ Cloudflare stateless edge runtime
+ signed immutable marketplace release
```

生产系统不运行旧 MCP 插件，不保留旧协议回退。

## 2. 核心产品原则

- 一个发布者可以拥有多个插件；
- 一个插件拥有稳定、不可抢占的完整 ID；
- 一个插件对应独立 Cloudflare 逻辑服务边界；
- 一个版本对应不可变部署与不可变安装包；
- 所有小程序 UI 使用 MCP Apps；
- 所有远程服务使用无状态 MCP SDK v2；
- 市场负责身份、审核、签名、权限、撤销和审计；
- CLI 直接从插件 Cloudflare 不可变 URL 下载；
- 普通发布者默认不接触 Cloudflare Token；
- 发布使用 GitHub Actions OIDC 短期凭证与 provenance；
- 生产设置 `legacy: "reject"`；
- 旧客户端只能升级，不能继续运行旧插件。

## 3. 用户角色

### 普通发布者

使用：

```bash
mahayana login
mahayana plugin init
mahayana plugin test
mahayana plugin publish --stage
mahayana plugin release
```

平台自动生成 MCP Apps 项目、构建 UI resource、部署无状态 Worker、生成不可变发布物、签名并提交审核。

### 高级发布者

可以自托管自己的 Cloudflare Worker，但必须：

- 使用 SDK v2；
- 使用 `createMcpHandler`；
- 设置 `legacy: "reject"`；
- 提供 MCP Apps manifest 和 `ui://` resources；
- 通过所有权、CSP、权限、签名、来源和审核检查。

### 安装用户

能够查看：

- 发布者与插件身份；
- MCP Apps 合规状态；
- 版本、权限、CSP、来源和审核等级；
- 安装、升级、撤销、回滚和安全状态。

### 审核人员

能够检查：

- MCP Apps 规范合规；
- SDK v2 和 stateless runtime；
- production 是否拒绝 legacy；
- UI resource、CSP 和 tool visibility；
- OIDC provenance、扫描、权限和不可变发布物。

## 4. 插件身份与部署

完整 ID 示例：

```text
io.mahayana.bhrum.hello
```

要求：

- 发布后不可被其他账号占用；
- 同一 `pluginId + version` 永远不可覆盖；
- 一个插件绑定一个稳定 Cloudflare Worker/Pages 服务；
- 版本通过 Worker version/deployment 或 Pages deployment 表达；
- 不为每个版本创建永久新项目；
- 插件之间不共享写 Secret、数据库、部署凭证或写权限。

## 5. MCP Apps 产品契约

每个正式插件必须：

- 声明扩展 `io.modelcontextprotocol/ui`；
- 注册至少一个 `ui://` resource；
- 使用 `text/html;profile=mcp-app`；
- Tool 使用 `_meta.ui.resourceUri` 关联 UI；
- View 使用官方 MCP Apps SDK；
- Host 使用 AppBridge 或规范一致实现；
- iframe sandbox；
- CSP 最小权限；
- Tool visibility 区分 `model` 与 `app`；
- 提供有意义的 `content` 和 `structuredContent`；
- 支持新标准的 `ui/initialize`、host context、display mode 和 teardown。

不得发布：

- 自定义 iframe message bridge；
- 依赖 `Mcp-Session-Id` 的插件；
- SDK v1 server；
- legacy handler；
- 只返回旧 HTML 入口而无 MCP Apps resource 的小程序。

## 6. 市场准入

正式 release 元数据必须包含：

- `runtime.kind = mcp-app`；
- `runtime.mcpSdk = v2`；
- `runtime.transport = stateless-http`；
- `runtime.legacy = false`；
- MCP Apps extension；
- `ui://` resource 清单；
- CSP 与外部域名；
- tool visibility；
- 权限；
- immutable package URL、SHA-256 和大小；
- OIDC provenance；
- 市场签名；
- 审核、撤销和过期状态。

未通过 MCP Apps 校验的版本只能显示 `migration_required`，不能进入公开等级或 production。

## 7. 发布与安装

发布链路：

```text
源码
→ GitHub Actions OIDC
→ MCP Apps build/test
→ SDK v2 stateless Worker deploy
→ legacy rejection test
→ immutable package
→ provenance + signature
→ review
→ production
```

安装链路：

```text
CLI → 市场签名元数据
CLI → 插件 Cloudflare URL 直连下载
CLI → 校验签名、哈希、来源、权限、撤销和 anti-rollback
CLI → 原子安装
Host → 仅以 MCP Apps 运行
```

## 8. 硬切换

采用单次 production cutover：

1. 先完成所有 Host；
2. 迁移所有官方插件；
3. 新模板和市场准入只接受 MCP Apps；
4. 全平台和真实 Cloudflare 验收；
5. 切换 production；
6. 删除旧 SDK、旧路由、旧 bridge 和旧测试；
7. 旧客户端显示强制升级。

不允许运行期双栈。

## 9. 审核等级

支持：

```text
private
unlisted
community
verified
official
blocked
migration_required
```

`community`、`verified`、`official` 必须满足 MCP Apps-only 准入。

## 10. 非目标

- 不保留旧 MCP 客户端兼容执行；
- 不保留旧插件 runtime；
- 不使用 R2 分发安装包或静态资源；
- 不让市场 Worker 永久代理全部下载字节；
- 不为每个版本创建独立虚拟机或永久 Worker 项目；
- 不以自定义 UI bridge 替代 MCP Apps。

## 11. 成功标准

至少一个真实第三方 MCP App 发布两个版本，并完成：

```text
init → test → stage → release → review → discover
→ render in Mahayana Host → render in another compliant Host
→ direct download → verify → install → run
→ permission diff → upgrade → rollback → revoke
→ reject legacy client → reject tampered package
```

同时所有官方小程序均完成 MCP Apps 迁移，生产依赖树和路由中不存在旧 MCP 运行代码。
