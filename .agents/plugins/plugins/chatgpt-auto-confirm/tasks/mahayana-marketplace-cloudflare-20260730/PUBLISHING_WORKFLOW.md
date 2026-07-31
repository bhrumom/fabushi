# 发布流程：大乘小程序

## 1. 目标体验

普通用户只需要：

```bash
mahayana login
mahayana plugin init
mahayana plugin test
mahayana plugin publish --stage
mahayana plugin release
```

平台负责 Cloudflare 项目、构建、部署、不可变包、签名、provenance 和审核。自托管是高级选项，不是默认入口。

## 2. 初始化

`mahayana plugin init` 生成：

```text
.codex-plugin/plugin.json
.mahayana/plugin.json
.mcp.json                  如适用
ui/                        如适用
runtime/                   如适用
mahayana.permissions.json
mahayana.publish.json
.github/workflows/mahayana-plugin-release.yml
```

`mahayana.publish.json` 只包含非 Secret 配置：

```json
{
  "schemaVersion": 1,
  "pluginId": "io.mahayana.bhrum.hello",
  "deploymentMode": "managed",
  "marketplace": "https://...",
  "releaseWorkflow": "mahayana-plugin-release.yml"
}
```

不得生成长期 Cloudflare Token 或市场写 Token。

## 3. 本地和 CI 测试

`mahayana plugin test` 至少执行：

- plugin manifest schema；
- Mahayana runtime manifest；
- MCP 配置；
- 权限清单；
- UI 入口和 CSP；
- 文件数量和大小；
- 路径安全；
- 本地安装、启动、健康检查和卸载；
- 构建可重复性摘要。

正式 release 仍必须在 GitHub Actions 中重新运行，不能信任用户本地结果。

## 4. Stage 流程

### 4.1 创建发布意图

CLI 以大乘账号调用市场：

```text
plugin ID
version
repository
workflow
commit SHA
stage=stage
```

市场返回 publish intent、OIDC audience、nonce 和过期时间。

### 4.2 GitHub Actions

工作流权限最小化：

```yaml
permissions:
  contents: read
  id-token: write
```

除只读依赖凭证外，不应配置长期市场发布 Token。工作流：

1. checkout 指定 commit；
2. 安装锁定版本工具；
3. 运行测试和扫描；
4. 构建规范化安装包；
5. 计算 SHA-256 和大小；
6. 获取 GitHub OIDC token；
7. 使用 publish intent + nonce 交换短期发布 token；
8. 创建或读取该插件独立 Cloudflare 项目；
9. 上传新 Worker version/Pages deployment，但不立刻替换 production；
10. 在不可变路径暴露包、manifest 和 provenance；
11. 从公网重新下载并核对字节；
12. 提交 stage release；
13. 上传 Actions 证据。

### 4.3 Stage 结果

CLI 输出：

```text
plugin ID
version
preview URL
immutable package URL
SHA-256
Actions run
review state
```

Stage 版本不能被普通市场搜索到。

## 5. Release 流程

`mahayana plugin release`：

1. 确认目标 stage release；
2. 展示版本不可复用提示；
3. 展示权限 diff；
4. 展示生产版本变化；
5. 提交审核；
6. 审核通过后签署版本元数据；
7. 创建 production deployment 指向该 Worker version；
8. 更新 `latest` 指针；
9. 写入 production history 和审计；
10. 从干净环境执行市场发现、直连下载、安装和启动 smoke test。

普通发布者首次 release：

```text
visibility=unlisted
review_state=pending
```

通过自动和人工审核后才进入 community 或更高等级。

## 6. 托管 Cloudflare 资源

平台为每个插件创建或绑定一个稳定服务：

```text
plugin ID → internal plugin UUID → Cloudflare project/service
```

每次版本发布创建 Cloudflare version/deployment，不创建永久新项目。

平台凭证管理要求：

- 仅平台受保护 environment 可使用；
- 权限限制到必要的 Workers/Pages 操作；
- 不返回给发布者；
- 不写日志；
- 定期轮换；
- 每次操作关联 plugin UUID 和审计事件。

## 7. 自托管流程

高级用户选择：

```bash
mahayana plugin publish --self-hosted https://plugin.example.workers.dev
```

流程：

1. 市场生成所有权 challenge；
2. 发布者在规定路径部署 challenge；
3. 市场验证 hostname 所有权；
4. 发布者部署不可变版本路径；
5. 市场重新获取包、manifest 和 provenance；
6. 校验 Cloudflare 域名、大小、SHA、权限和来源；
7. 生成市场签名元数据；
8. 进入相同审核流程。

自托管发布者负责服务可用性，但不能修改已登记正式版本内容，也不能绕过撤销和审核。

## 8. Production 提升

生产提升不重新构建。它只能引用已验证的 stage release：

```text
verified release
  → approved review
  → Cloudflare deployment points production to version ID
  → signed marketplace metadata becomes installable
```

如果生产提升后 smoke test 失败：

- 自动或人工回滚到前一已批准版本；
- 标记新版本 suspended/revoked；
- 保存失败证据；
- 不覆盖任何版本产物。

## 9. 回滚

```bash
mahayana plugin rollback 1.0.0
```

要求：

- 目标版本存在且未 blocked；
- 显示权限和数据兼容差异；
- 创建新的 Cloudflare deployment 指向旧 version ID；
- 更新 production history；
- `latest` 指针更新；
- 版本包和签名历史保持不变；
- 执行生产 smoke test。

## 10. 撤销

```bash
mahayana plugin revoke 1.0.0 --reason security
```

撤销产生新签名安全状态元数据。被撤销版本：

- 不允许新安装；
- 不允许升级到该版本；
- 已安装用户收到安全状态；
- 可以指向 replacement version；
- 保留包和审计证据，除非法律或紧急安全流程要求隔离内容。

## 11. 发布版本和包版本

推荐语义版本。版本字符串必须唯一，不能使用范围。市场排序：

- 合法 semver 按 semver；
- prerelease 按 semver；
- 非 semver 只用于 legacy 兼容，不应成为新托管发布默认。

元数据小改也不能覆盖原版本；必须发布新版本或签发新的 `metadataVersion`，其中 package 内容保持不变。

## 12. 发布证据包

每个正式 release 的 Actions artifact 至少包含：

```text
release-receipt.json
plugin.json
permissions.json
provenance.json
package.sha256
scan-summary.json
install-smoke.json
deployment-summary.json
```

`release-receipt.json` 记录：

- plugin ID/version；
- repository/commit/workflow/run；
- Cloudflare project/version/deployment；
- immutable URLs；
- SHA/size；
- market release ID；
- signature key ID；
- review state；
- smoke results。

## 13. 禁止做法

- 普通用户手工配置平台 Cloudflare Token；
- 把长期发布 Token 放入插件仓库 Secrets；
- 使用测试账号凭证代替生产 OIDC；
- 发布同一版本的新字节；
- 每个版本创建永久新 Worker 项目；
- 使用 R2 分发包或静态资源；
- 市场 Worker 代理全部下载字节；
- Stage 未验证就直接更新 production；
- 仅凭本地构建结果发布；
- 只有 SHA-256，没有签名和 provenance。
