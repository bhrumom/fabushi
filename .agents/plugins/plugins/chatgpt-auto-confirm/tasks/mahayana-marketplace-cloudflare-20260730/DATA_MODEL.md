# 数据模型：MCP Apps-only 大乘市场 v2

## 1. 设计原则

- 插件身份、版本、部署和审核分离；
- 正式版本只追加、不覆盖；
- MCP Apps runtime 合规是正式发布的必填数据；
- 旧插件只能作为迁移记录存在，不能安装或运行；
- 所有安全决策可从数据库和审计事件复现。

## 2. `publisher_namespaces`

```text
id
namespace unique
publisher_user_id
verification_type
verification_subject
verification_state
verified_at
created_at
updated_at
```

## 3. `marketplace_plugins`

```text
plugin_uuid immutable UUID
plugin_id unique stable ID
publisher_user_id
namespace_id
display_name
description
deployment_mode managed | self_hosted
visibility private | unlisted | public
review_tier unlisted | community | verified | official | blocked | migration_required
review_state pending | approved | rejected | suspended
latest_version
production_version
migration_state ready | migration_required | blocked
created_at
updated_at
```

`production_version` 只能引用已批准、未撤销且 MCP Apps 合规的 release。

## 4. `plugin_deployments`

```text
id
plugin_uuid
provider cloudflare
mode managed | self_hosted
provider_project_ref
service_name
stable_hostname
mcp_route
ownership_state
created_at
updated_at
```

每个插件一个 active 主服务；不同插件不得共享写凭证、Secret 或数据库边界。

## 5. `plugin_releases`

```text
id
plugin_uuid
plugin_id
version
release_status staged | pending | approved | rejected | revoked | deprecated | migration_required
review_tier
package_url
package_sha256
package_size
package_content_type
manifest_url
provenance_url
homepage_url
runtime_url
runtime_kind              mcp-app
mcp_sdk_major             2
transport_mode            stateless-http
legacy_allowed            false
mcp_apps_extension        io.modelcontextprotocol/ui
ui_resources_json
ui_mime_types_json
ui_display_modes_json
ui_csp_json
tool_visibility_json
host_min_version
permissions_json
source_repository
source_commit_sha
source_workflow
source_run_id
metadata_version
metadata_expires_at
published_at
approved_at
revoked_at
revocation_reason_code
replacement_version
tuf_target_path
```

唯一约束：

```text
UNIQUE(plugin_id, version)
UNIQUE(package_url)
```

正式 release 的数据库约束必须保证：

- `runtime_kind = 'mcp-app'`；
- `mcp_sdk_major = 2`；
- `transport_mode = 'stateless-http'`；
- `legacy_allowed = false`；
- extension、UI resource 和 MIME 非空。

## 6. `plugin_release_deployments`

```text
id
release_id
provider_version_id
provider_deployment_id
deployment_stage preview | production | rollback
preview_url
mcp_url
legacy_rejection_verified boolean
stateless_cross_edge_verified boolean
created_by
created_at
superseded_at
```

Production 只能引用 `legacy_rejection_verified = true` 的记录。

## 7. `plugin_ui_resources`

```text
id
release_id
resource_uri
mime_type
content_sha256
csp_json
display_modes_json
cache_policy_json
created_at
```

约束：

- URI 必须为 `ui://`；
- MIME 必须为 `text/html;profile=mcp-app`；
- 同一 release 内 URI 唯一；
- 内容哈希与实际 resource 一致。

## 8. `plugin_tool_visibility`

```text
release_id
tool_name
model_visible boolean
app_visible boolean
risk_class read | write | destructive | open_world
permission_key
created_at
```

跨插件 app-only Tool 调用永远不允许。

## 9. `plugin_permissions`

```text
release_id
permission_type network | filesystem | secret | command | mcp_tool | ui_surface | browser
permission_value
access_level
required
created_at
```

支持版本间权限 diff；市场元数据与包内 manifest 必须一致。

## 10. OIDC 与 provenance

### `publish_intents`

```text
id
plugin_uuid
version
stage
publisher_user_id
repository
workflow
commit_sha
github_environment
oidc_audience
nonce_hash
nonce_used_at
expires_at
created_at
```

### `release_provenance`

```text
release_id
repository
commit_sha
workflow_path
workflow_ref
run_id
builder_identity
artifact_sha256
attestation_url
verified_at
verification_result
raw_digest
```

不得存原始 token、完整 OIDC JWT 或 Secret。

## 11. 签名、审核和撤销

保留独立表：

- `marketplace_signing_keys`；
- `release_signatures`；
- `plugin_reviews`；
- `plugin_revocations`；
- `plugin_production_history`；
- `marketplace_audit_events`。

审核 checks 必须保存 MCP Apps、SDK v2、stateless、legacy rejected、UI resource、CSP、visibility 和 browser smoke 结果。

## 12. 旧插件迁移记录

旧记录不得迁入正式 `plugin_releases` 后伪装成可运行 v2。使用独立表或独立不可运行状态：

```text
legacy_plugin_inventory
legacy_plugin_id
legacy_version
source_reference
migration_state detected | queued | converted | retired
replacement_release_id nullable
last_seen_at
```

规则：

- 旧记录不可成为 production；
- 不生成可安装 URL；
- 不生成假签名或假 provenance；
- 新 Host 不读取其 runtime；
- 仅迁移工具、升级 UI 和审计可读取。

## 13. 客户端本地状态

```json
{
  "pluginId": "io.mahayana.bhrum.hello",
  "installedVersion": "1.1.0",
  "installedSha256": "...",
  "runtimeKind": "mcp-app",
  "mcpSdkMajor": 2,
  "legacyAllowed": false,
  "uiResources": ["ui://..."],
  "permissions": {},
  "csp": {},
  "reviewTier": "community",
  "migrationState": "ready",
  "highestKnownSafeVersion": "1.1.0",
  "metadataVersion": 4,
  "revocationState": "clear"
}
```

旧本地插件状态改为：

```json
{
  "migrationState": "migration_required",
  "runnable": false,
  "upgradeTarget": "1.1.0"
}
```

## 14. 审计事件

至少记录：

```text
plugin.created
release.staged
mcp_apps.validated
sdk_v2.validated
legacy.rejected
ui_resource.validated
csp.validated
tool_visibility.validated
release.approved
release.promoted
plugin.migration_required
host.upgrade_required
release.revoked
plugin.blocked
```

不得记录 token、Secret、敏感表单值或安装包正文。
