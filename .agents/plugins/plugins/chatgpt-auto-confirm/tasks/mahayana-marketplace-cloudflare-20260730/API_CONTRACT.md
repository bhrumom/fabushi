# API 契约：MCP Apps-only 大乘市场 v2

## 1. 通用规则

- 基础路径：`/v2/marketplace`。
- 写操作要求大乘账号认证；发布凭证交换要求 GitHub Actions OIDC。
- 所有正式版本元数据规范化后签名。
- 所有新发布接口只接受 MCP Apps + SDK v2 + stateless runtime。
- 不提供旧 MCP 发布 API、运行代理或 legacy negotiation。
- 旧客户端访问 MCP runtime 时由插件 endpoint 返回 `MCP_APPS_HOST_UPGRADE_REQUIRED`。

## 2. 创建插件

### `POST /v2/marketplace/plugins`

```json
{
  "namespace": "io.mahayana.bhrum",
  "slug": "hello",
  "displayName": "Hello",
  "deploymentMode": "managed",
  "visibility": "private"
}
```

返回稳定 `pluginId` 和内部 UUID。完整 ID 发布后不可被其他账号占用。

## 3. 创建发布意图

### `POST /v2/marketplace/plugins/{pluginId}/publish-intents`

```json
{
  "version": "1.0.0",
  "stage": "stage",
  "repository": "bhrum/example-plugin",
  "workflow": ".github/workflows/mahayana-plugin-release.yml",
  "commitSha": "...",
  "deploymentMode": "managed"
}
```

同一 `pluginId + version` 已存在时返回 `version_already_exists`。

## 4. OIDC 交换

### `POST /v2/marketplace/publish-tokens/exchange`

验证：issuer、audience、repository、workflow、commit、environment、actor、plugin owner、intent expiry 和 nonce。

返回短期、单插件、单版本、单阶段 token。

## 5. 提交 stage

### `POST /v2/marketplace/plugins/{pluginId}/releases/stage`

```json
{
  "version": "1.0.0",
  "cloudflare": {
    "projectId": "internal-reference",
    "versionId": "...",
    "previewUrl": "https://...",
    "mcpUrl": "https://.../mcp"
  },
  "runtime": {
    "kind": "mcp-app",
    "mcpSdk": "v2",
    "transport": "stateless-http",
    "legacy": false,
    "extension": "io.modelcontextprotocol/ui"
  },
  "ui": {
    "resources": ["ui://io.mahayana.bhrum.hello/main"],
    "mimeTypes": ["text/html;profile=mcp-app"],
    "displayModes": ["inline", "fullscreen"],
    "csp": {},
    "toolVisibility": {}
  },
  "package": {
    "url": "https://.../mahayana/releases/1.0.0/<sha>/plugin.tar.gz",
    "sha256": "...",
    "size": 12345,
    "contentType": "application/gzip"
  },
  "manifestUrl": "https://.../plugin.json",
  "provenanceUrl": "https://.../provenance.json",
  "permissions": {},
  "source": {
    "repository": "https://github.com/bhrum/example-plugin",
    "commitSha": "...",
    "workflow": ".github/workflows/mahayana-plugin-release.yml",
    "runId": "123456"
  }
}
```

服务端必须自行完成：

1. 拉取 package/manifest/provenance；
2. 验证 URL、size、SHA、pluginId、version 和 permissions；
3. 验证 SDK v2 manifest；
4. 调用 `/mcp` 执行 MCP Apps conformance；
5. 读取全部 `ui://` resources；
6. 验证 MIME、CSP 和 tool visibility；
7. 验证 production/preview endpoint 拒绝 legacy 请求；
8. 验证 sandbox browser smoke；
9. 验证 provenance。

任一失败不得创建可审核 release。

## 6. Promote

### `POST /v2/marketplace/plugins/{pluginId}/releases/{version}/promote`

只有 stage 全部通过、审核批准且 `legacyRejected = true` 时才能提升 production。

## 7. 浏览与详情

### `GET /v2/marketplace/plugins`

仅返回获批准且 MCP Apps 合规的公开版本。

### `GET /v2/marketplace/plugins/{pluginId}`

返回：

- publisher/review tier；
- production version；
- MCP Apps compliance；
- SDK v2/stateless/legacy rejected；
- UI resources、display modes、CSP、tool visibility；
- permissions、source、signature、revocation。

### `GET /v2/marketplace/plugins/{pluginId}/releases/{version}`

签名主体至少包含：

```json
{
  "schemaVersion": 2,
  "protocol": "mahayana.plugin-release.v2",
  "pluginId": "...",
  "version": "1.0.0",
  "runtime": {
    "kind": "mcp-app",
    "mcpSdk": "v2",
    "transport": "stateless-http",
    "legacy": false,
    "extension": "io.modelcontextprotocol/ui"
  },
  "ui": {
    "resources": ["ui://..."],
    "mimeTypes": ["text/html;profile=mcp-app"],
    "csp": {},
    "toolVisibility": {}
  },
  "package": {},
  "permissions": {},
  "source": {},
  "publishedAt": "...",
  "expiresAt": "...",
  "metadataVersion": 1
}
```

## 8. 下载

### `GET /v2/marketplace/plugins/{pluginId}/releases/{version}/download`

只允许：

- `307` 到签名元数据中的不可变 Cloudflare URL；或
- 返回直接 URL、SHA、size 和签名 metadata URL。

市场不得长期代理包正文。

## 9. 审核

### `POST /v2/marketplace/plugins/{pluginId}/releases/{version}/reviews`

审核 checks 必须包括：

```json
{
  "mcpApps": "passed",
  "sdkV2": "passed",
  "stateless": "passed",
  "legacyRejected": "passed",
  "uiResources": "passed",
  "csp": "passed",
  "toolVisibility": "passed",
  "packageSafety": "passed",
  "permissions": "passed",
  "provenance": "passed",
  "runtimeSmoke": "passed"
}
```

## 10. 回滚、撤销和封禁

- rollback 只能指向已批准的 MCP Apps 版本；
- revoke 阻止该版本新安装和升级；
- blocked 阻止插件整体安装、升级和启动；
- 不允许回滚到旧 MCP runtime 版本。

## 11. 旧插件状态

旧插件元数据可以被迁移工具读取，但 API 返回：

```json
{
  "migrationState": "migration_required",
  "installable": false,
  "runnable": false,
  "requiredRuntime": "mcp-app"
}
```

不提供兼容执行 URL。

## 12. 稳定错误码

至少包括：

```text
mcp_apps_required
mcp_apps_extension_missing
ui_resource_missing
ui_mime_invalid
app_bridge_conformance_failed
csp_invalid
tool_visibility_invalid
sdk_v2_required
stateless_runtime_required
legacy_runtime_rejected
legacy_endpoint_still_enabled
host_upgrade_required
plugin_migration_required
version_already_exists
oidc_invalid
oidc_claim_mismatch
publish_nonce_replayed
package_hash_mismatch
manifest_mismatch
permission_mismatch
provenance_invalid
signature_invalid
metadata_expired
release_revoked
plugin_blocked
```

CLI、Web、Flutter 和 Cloudflare logs 使用一致错误码。
