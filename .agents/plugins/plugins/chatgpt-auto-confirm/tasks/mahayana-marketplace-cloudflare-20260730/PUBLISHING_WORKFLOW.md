# 发布流程：MCP Apps-only 大乘小程序

## 1. 默认体验

```bash
mahayana login
mahayana plugin init
mahayana plugin test
mahayana plugin publish --stage
mahayana plugin release
```

平台负责 MCP Apps 模板、SDK v2 Worker、Cloudflare 项目、构建、扫描、不可变包、签名、provenance 和审核。自托管是高级选项。

## 2. `plugin init`

只生成新架构：

```text
.codex-plugin/plugin.json
.mahayana/plugin.json
.mcp-app.json
ui/
runtime/
mahayana.permissions.json
mahayana.publish.json
.github/workflows/mahayana-plugin-release.yml
```

模板必须包含：

- `@modelcontextprotocol/server` SDK v2；
- `createMcpHandler`；
- `legacy: "reject"`；
- `@modelcontextprotocol/ext-apps`；
- `ui://` resource；
- `text/html;profile=mcp-app`；
- App/View code；
- CSP 和 tool visibility；
- text + structured result。

不得生成 legacy template 或长期发布 Token。

## 3. `plugin test`

至少执行：

- manifest/schema；
- SDK v2 import；
- stateless handler；
- legacy rejection；
- MCP Apps extension；
- `ui://` resource 和 MIME；
- AppBridge handshake；
- sandbox/CSP；
- model/app visibility；
- 权限清单；
- 包边界和路径安全；
- 本地安装与启动；
- browser smoke。

正式 release 在 Actions 中重新执行。

## 4. Stage

### 发布意图

CLI 提交 plugin ID、version、repository、workflow、commit 和 stage。市场返回 OIDC audience、nonce 和 expiry。

### GitHub Actions

最小权限：

```yaml
permissions:
  contents: read
  id-token: write
```

流程：

1. checkout 指定 commit；
2. 安装锁定版本依赖；
3. 运行 MCP Apps/SDK v2 conformance；
4. 构建 UI resources 和 Worker；
5. 扫描依赖、Secret、CSP 和权限；
6. 获取 OIDC token 并交换短期发布凭证；
7. 创建/读取每插件独立 Cloudflare 项目；
8. 部署 preview Worker version；
9. 验证 `/mcp` 正常调用；
10. 验证 legacy 请求被拒绝；
11. 读取并渲染 `ui://` resource；
12. 验证 AppBridge、sandbox、CSP 和 visibility；
13. 生成不可变 package/manifest/provenance；
14. 从公网重新获取并核对字节；
15. 提交 stage release 和证据包。

Stage 不得进入公开搜索。

## 5. Release

`mahayana plugin release`：

1. 选择已验证 stage；
2. 展示版本不可复用；
3. 展示权限、CSP 和 tool visibility diff；
4. 提交审核；
5. 审核确认 MCP Apps、SDK v2、stateless 和 legacy rejected；
6. 签署版本元数据；
7. production deployment 指向该 Worker version；
8. 更新 `latest` 指针；
9. 从干净环境执行市场、下载、安装和 MCP Apps Host smoke；
10. 写审计和 production history。

Production 不重新构建，只提升已验证的不可变 stage。

## 6. 托管 Cloudflare

每插件一个稳定项目：

```text
plugin ID → plugin UUID → Cloudflare project/service
```

每次发布创建 version/deployment，不创建永久新项目。

平台凭证只存在于受保护环境，不下发给发布者、不写日志、定期轮换。

## 7. 自托管

```bash
mahayana plugin publish --self-hosted https://plugin.example.workers.dev
```

要求：

- 所有权 challenge；
- Cloudflare HTTPS；
- SDK v2 `createMcpHandler`；
- `legacy:"reject"`；
- MCP Apps resources；
- 不可变包；
- provenance；
- 相同审核和签名。

市场必须真实探测 endpoint，不能只相信 manifest。

## 8. 版本与不可变路径

```text
/mahayana/releases/<version>/<sha>/plugin.tar.gz
/mahayana/releases/<version>/<sha>/plugin.json
/mahayana/releases/<version>/<sha>/provenance.json
```

- version 唯一；
- 同路径字节不可变化；
- `latest` 只指向 production；
- 回滚只切 deployment；
- 撤销不删除审计。

不允许非 semver 旧格式作为新发布。

## 9. 发布证据包

```text
release-receipt.json
plugin.json
mcp-app-manifest.json
ui-resources.json
csp-report.json
tool-visibility.json
legacy-rejection.json
permissions.json
provenance.json
package.sha256
scan-summary.json
host-smoke.json
external-host-smoke.json
deployment-summary.json
```

收据记录 plugin/version、repository/commit/workflow/run、Cloudflare project/version/deployment、immutable URLs、SHA/size、MCP Apps/SDK 版本、signature、review 和 smoke results。

## 10. 回滚与撤销

- 只能回滚到已批准的 MCP Apps release；
- 不能回滚到旧 runtime；
- 撤销版本不能新安装或升级；
- blocked 插件不能启动；
- production smoke 失败时回滚到上一 MCP Apps-only deployment。

## 11. 旧插件

旧插件只进入迁移 inventory：

- 不可 stage；
- 不可 release；
- 不可 production；
- 不可安装或启动；
- 发布者必须重新构建 MCP Apps 版本。

## 12. 禁止做法

- legacy template 或 handler；
- SDK v1 server；
- MCP session ID/store；
- 自定义 iframe bridge；
- 生产兼容 lane；
- 普通用户配置平台 Cloudflare Token；
- 长期市场写 Token；
- 测试账号代替 OIDC；
- 同版本覆盖；
- 每版本永久新 Worker；
- R2 分发包或静态资源；
- 市场代理全部下载字节；
- 未验证就提升 production；
- 只有 SHA、没有签名和 provenance。
