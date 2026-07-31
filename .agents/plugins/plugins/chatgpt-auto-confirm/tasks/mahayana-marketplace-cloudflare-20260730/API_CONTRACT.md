# API 契约：大乘小程序市场 v2

## 1. 通用约定

- 基础路径：`/v2/marketplace`。
- JSON 响应必须包含稳定 `errorCode`，不能只返回中文错误文本。
- 时间使用 RFC 3339 UTC。
- plugin ID 和 version 放入 URL 时必须逐段编码和规范化。
- 所有写操作要求大乘账号认证；发布凭证交换还要求 GitHub Actions OIDC。
- 版本元数据的安全字段必须规范化后签名。
- v1 接口在迁移期保留，新客户端优先 v2。

## 2. 创建插件身份

### `POST /v2/marketplace/plugins`

请求：

```json
{
  "namespace": "io.mahayana.bhrum",
  "slug": "hello",
  "displayName": "Hello",
  "description": "示例插件",
  "deploymentMode": "managed",
  "visibility": "private"
}
```

响应：

```json
{
  "pluginId": "io.mahayana.bhrum.hello",
  "pluginUuid": "...",
  "publisherId": "...",
  "deploymentMode": "managed",
  "visibility": "private",
  "reviewTier": "unlisted",
  "createdAt": "..."
}
```

错误：

- `namespace_not_owned`
- `plugin_id_taken`
- `invalid_plugin_identity`
- `deployment_mode_not_allowed`

## 3. 创建发布意图

### `POST /v2/marketplace/plugins/{pluginId}/publish-intents`

请求：

```json
{
  "version": "1.0.0",
  "stage": "stage",
  "repository": "bhrum/example-plugin",
  "workflow": "mahayana-plugin-release.yml",
  "commitSha": "...",
  "deploymentMode": "managed"
}
```

响应：

```json
{
  "publishIntentId": "...",
  "nonce": "...",
  "audience": "mahayana-plugin-publish",
  "expiresAt": "...",
  "requiredClaims": {
    "repository": "bhrum/example-plugin",
    "workflow": "mahayana-plugin-release.yml",
    "commitSha": "..."
  }
}
```

同一 `pluginId + version` 已存在时立即返回 `version_already_exists`。

## 4. OIDC 交换短期发布凭证

### `POST /v2/marketplace/publish-tokens/exchange`

请求头：

```text
Authorization: Bearer <GitHub Actions OIDC JWT>
```

请求：

```json
{
  "publishIntentId": "...",
  "nonce": "..."
}
```

服务端验证：

- issuer；
- audience；
- repository owner/name；
- workflow ref；
- commit SHA；
- environment；
- actor 和 repository visibility 策略；
- publish intent 未过期；
- nonce 未使用；
- plugin ID 仍属于该发布者。

响应：

```json
{
  "accessToken": "short-lived-token",
  "tokenType": "Bearer",
  "expiresIn": 600,
  "scope": [
    "plugin:io.mahayana.bhrum.hello",
    "version:1.0.0",
    "stage:stage"
  ]
}
```

错误：

- `oidc_invalid`
- `oidc_claim_mismatch`
- `publish_intent_expired`
- `publish_nonce_replayed`
- `plugin_owner_mismatch`

## 5. 提交 stage 构建结果

### `POST /v2/marketplace/plugins/{pluginId}/releases/stage`

使用短期发布 token。

请求：

```json
{
  "version": "1.0.0",
  "deploymentMode": "managed",
  "cloudflare": {
    "projectId": "internal-reference",
    "versionId": "...",
    "previewUrl": "https://..."
  },
  "package": {
    "url": "https://.../mahayana/releases/1.0.0/<sha>/plugin.tar.gz",
    "sha256": "...",
    "size": 12345,
    "contentType": "application/gzip"
  },
  "manifestUrl": "https://.../plugin.json",
  "provenanceUrl": "https://.../provenance.json",
  "permissions": {
    "network": [],
    "filesystem": [],
    "secrets": [],
    "commands": false,
    "mcpTools": [],
    "uiSurfaces": ["chatPanel"]
  },
  "source": {
    "repository": "https://github.com/bhrum/example-plugin",
    "commitSha": "...",
    "workflow": ".github/workflows/mahayana-plugin-release.yml",
    "runId": "123456"
  }
}
```

服务端必须重新获取 manifest、包和 provenance，验证 URL、大小、SHA、gzip、插件 ID、版本、权限和来源，不信任客户端声明。

响应：

```json
{
  "releaseId": "...",
  "status": "staged",
  "reviewState": "pending",
  "immutableMetadataUrl": "https://market.../v2/.../metadata",
  "verification": {
    "packageVerified": true,
    "provenanceVerified": true,
    "permissionsVerified": true
  }
}
```

## 6. 提交正式 release

### `POST /v2/marketplace/plugins/{pluginId}/releases/{version}/promote`

请求：

```json
{
  "releaseId": "...",
  "target": "production",
  "releaseNotes": "..."
}
```

行为：

- stage 验证未通过时拒绝；
- 普通发布者进入 `unlisted + pending`；
- 管理员/自动策略批准后才更新生产别名；
- 创建市场签名版本元数据；
- 写入审计事件。

## 7. 浏览和详情

### `GET /v2/marketplace/plugins`

查询：

```text
?q=&platform=&reviewTier=&publisher=&cursor=&limit=
```

默认只返回可公开发现且获批准的插件。`unlisted` 不能出现在普通搜索中。

### `GET /v2/marketplace/plugins/{pluginId}`

返回展示资料、发布者、信任等级、生产版本、权限摘要、源码和安全状态。

### `GET /v2/marketplace/plugins/{pluginId}/releases/{version}`

返回签名版本元数据。建议响应结构：

```json
{
  "signed": {
    "schemaVersion": 2,
    "protocol": "mahayana.plugin-release.v2",
    "metadataVersion": 1,
    "pluginId": "...",
    "version": "1.0.0",
    "status": "approved",
    "reviewTier": "community",
    "package": {
      "url": "https://.../<sha>/plugin.tar.gz",
      "sha256": "...",
      "size": 12345,
      "contentType": "application/gzip"
    },
    "permissions": {},
    "source": {},
    "provenanceUrl": "...",
    "publishedAt": "...",
    "expiresAt": "..."
  },
  "signatures": [
    {
      "keyId": "marketplace-2026-01",
      "algorithm": "ed25519",
      "signature": "base64url"
    }
  ]
}
```

动态统计、评价和下载次数不得放入被签名的不可变 release 主体。

## 8. 下载兼容端点

### `GET /v2/marketplace/plugins/{pluginId}/releases/{version}/download`

允许两种兼容行为：

- 返回 `307` 到签名元数据中的不可变 Cloudflare URL；或
- 返回包含直接 URL、SHA、大小和签名元数据 URL 的 JSON。

禁止市场 Worker读取并持续转发安装包正文。

## 9. 审核

### `POST /v2/marketplace/plugins/{pluginId}/releases/{version}/reviews`

请求：

```json
{
  "decision": "approve",
  "reviewTier": "community",
  "notes": "...",
  "checks": {
    "manifest": "passed",
    "packageSafety": "passed",
    "permissions": "passed",
    "provenance": "passed",
    "runtimeSmoke": "passed"
  }
}
```

只有具备审核权限的账号可调用。每次审核写入不可变审计记录。

## 10. 回滚

### `POST /v2/marketplace/plugins/{pluginId}/rollbacks`

请求：

```json
{
  "fromVersion": "1.1.0",
  "toVersion": "1.0.0",
  "reason": "production regression"
}
```

要求：

- 目标版本仍存在且未 blocked；
- 不修改目标版本内容；
- 创建新的 deployment 记录；
- 更新 production alias；
- 写审计事件；
- 返回当前生产版本和 Cloudflare deployment ID。

## 11. 撤销和封禁

### `POST /v2/marketplace/plugins/{pluginId}/releases/{version}/revoke`

请求：

```json
{
  "reasonCode": "malware_detected",
  "message": "...",
  "replacementVersion": "1.0.2"
}
```

### `POST /v2/marketplace/plugins/{pluginId}/block`

插件整体 blocked 后：

- 不出现在普通搜索；
- 新安装和升级被拒绝；
- 已安装客户端获得安全状态；
- 管理员可以查看审计和证据。

## 12. 自托管所有权

### `POST /v2/marketplace/plugins/{pluginId}/deployment-challenges`

响应 challenge path/token。

### `POST /v2/marketplace/plugins/{pluginId}/deployment-challenges/verify`

市场从 HTTPS Cloudflare URL读取 challenge，验证后记录 hostname、账户/项目证据和有效期。

## 13. 稳定错误码

至少实现：

```text
invalid_request
unauthenticated
forbidden
namespace_not_owned
plugin_id_taken
version_already_exists
invalid_deployment_url
deployment_not_cloudflare
deployment_ownership_failed
mutable_release_url
oidc_invalid
oidc_claim_mismatch
publish_intent_expired
publish_nonce_replayed
package_fetch_failed
package_too_large
package_format_invalid
package_size_mismatch
package_hash_mismatch
manifest_mismatch
permission_mismatch
provenance_invalid
signature_invalid
metadata_expired
rollback_rejected
release_revoked
plugin_blocked
review_required
```

CLI、Web 和 Flutter UI 必须将错误码映射为一致、可操作的文案。
