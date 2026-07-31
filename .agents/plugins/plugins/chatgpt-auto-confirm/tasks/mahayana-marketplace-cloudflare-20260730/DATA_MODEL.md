# 数据模型：大乘小程序市场 v2

## 1. 设计原则

- 插件身份与展示名称分离；
- 插件与版本分离；
- 版本记录只追加，不覆盖；
- 部署记录与发布记录分离；
- 审核、签名、撤销、权限和 provenance 可独立审计；
- 兼容现有 `marketplace_plugins` 和 `plugin_releases`；
- 所有安全决策必须能从数据库和审计事件复现。

## 2. `publisher_namespaces`

建议字段：

```text
id
namespace                 unique
publisher_user_id
verification_type         account | github | dns | http
verification_subject
verification_state        pending | verified | revoked
verified_at
created_at
updated_at
```

约束：

- namespace 全局唯一；
- 只有 verified namespace 可创建公开插件；
- namespace 迁移需要管理员审计事件；
- 被撤销 namespace 不能发布新版本。

## 3. `marketplace_plugins`

保留现有表并扩展：

```text
plugin_uuid               internal immutable UUID
plugin_id                 external stable unique ID
publisher_user_id
namespace_id
display_name
description
category
deployment_mode           managed | self_hosted
visibility                private | unlisted | public
review_tier               unlisted | community | verified | official | blocked
review_state              pending | approved | rejected | suspended
latest_version
production_version
created_at
updated_at
blocked_at
blocked_reason_code
```

约束：

- `plugin_id` 全局唯一且创建后不可修改；
- `production_version` 必须引用已批准且未撤销 release；
- blocked 时不能创建公开发布和新安装元数据。

## 4. `plugin_deployments`

```text
id
plugin_uuid
provider                  cloudflare
mode                      managed | self_hosted
provider_account_ref      encrypted/internal reference
provider_project_ref
service_name
stable_hostname
ownership_state           pending | verified | revoked
ownership_verified_at
created_at
updated_at
```

约束：

- 每个插件只允许一个 active 主 deployment 映射；
- provider credential 不直接存入普通表；
- 不同插件不能复用具有写权限的 project ref，除非平台实现经过验证的强隔离多租户服务；本任务默认禁止。

## 5. `plugin_releases`

从现有表迁移扩展：

```text
id
plugin_uuid
plugin_id
version
release_status            staged | pending | approved | rejected | revoked | deprecated
review_tier
package_url
package_sha256
package_size
package_content_type
manifest_url
provenance_url
homepage_url
runtime_url
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
legacy_package_key        compatibility only
tuf_target_path           future-compatible
```

唯一约束：

```text
UNIQUE(plugin_id, version)
UNIQUE(package_url)
```

正式版本的 `package_url` 必须包含 version 和 SHA-256。已撤销版本仍保留记录。

## 6. `plugin_release_deployments`

发布版本和 Cloudflare version/deployment 的映射：

```text
id
release_id
provider_version_id
provider_deployment_id
deployment_stage           preview | production | rollback
preview_url
created_by
created_at
superseded_at
```

一个 release 可以经历 preview、promotion 和 rollback 引用，但不能改变其包内容。

## 7. `plugin_permissions`

可以规范化存储，也可同时保留签名 JSON 快照：

```text
release_id
permission_type            network | filesystem | secret | command | mcp_tool | ui_surface
permission_value
access_level
required
created_at
```

要求：

- 每个 release 保存完整权限快照；
- 支持计算任意两版本的权限 diff；
- 市场元数据与包内 manifest 必须一致；
- 权限变化写审计事件。

## 8. `publish_intents`

```text
id
plugin_uuid
version
stage                      stage | release
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

约束：

- nonce 只保存哈希；
- 只能交换一次；
- 过期后不能使用；
- scope 与 plugin/version/stage 严格绑定。

## 9. `publish_credentials`

不保存原始 token，只保存审计摘要：

```text
id
publish_intent_id
token_jti_hash
issued_at
expires_at
used_at
claims_digest
result
```

实际短期 token 使用签名 JWT 或等价机制，无需持久化明文。

## 10. `release_provenance`

```text
release_id
predicate_type
repository
commit_sha
workflow_path
workflow_ref
run_id
runner_environment
builder_identity
artifact_sha256
attestation_url
transparency_log_url
verified_at
verification_result
raw_digest
```

原始 provenance 可存于插件服务不可变 URL，市场保存可验证摘要和关键索引。

## 11. `marketplace_signing_keys`

```text
key_id
algorithm
public_key
role                      root | targets | online
state                     active | retiring | revoked
not_before
not_after
created_at
revoked_at
```

私钥不能以明文存入 D1。数据库只存公钥、状态和审计信息；签名服务使用受保护 Secret/KMS/平台密钥能力。

## 12. `release_signatures`

```text
release_id
key_id
algorithm
canonical_payload_sha256
signature
signed_at
```

签名覆盖不可变 release 元数据。更新审核状态、撤销状态或过期时间时，应生成新 `metadata_version` 和新签名，而不是修改旧签名记录。

## 13. `plugin_reviews`

```text
id
release_id
reviewer_user_id
decision                  approve | reject | request_changes | suspend
review_tier
checks_json
notes
created_at
```

审核历史只追加。插件当前状态由最新有效审核决定，但旧决定不可删除。

## 14. `plugin_revocations`

```text
id
plugin_uuid
release_id nullable
scope                     plugin | release
reason_code
message
replacement_version
issued_by
metadata_version
effective_at
expires_at nullable
created_at
```

支持单版本撤销和插件整体 blocked。CLI 获取签名元数据时必须看到当前有效撤销。

## 15. `plugin_production_history`

```text
id
plugin_uuid
from_release_id nullable
to_release_id
operation                 promote | rollback | security_rollback
reason
provider_deployment_id
actor_user_id
created_at
```

用于复现生产别名每次变化。

## 16. `marketplace_audit_events`

```text
id
event_type
actor_type                user | workflow | service | admin
actor_id
publisher_user_id nullable
plugin_uuid nullable
release_id nullable
request_id
source_ip_hash nullable
metadata_json
created_at
```

事件示例：

```text
namespace.claimed
plugin.created
publish_intent.created
oidc.exchanged
release.staged
release.verified
release.approved
release.promoted
release.rolled_back
release.revoked
plugin.blocked
signing_key.rotated
install.reported
```

禁止写入 token、Secret、完整 OIDC JWT 或安装包正文。

## 17. 客户端本地状态

每个已安装插件保存：

```json
{
  "pluginId": "io.mahayana.bhrum.hello",
  "installedVersion": "1.1.0",
  "installedSha256": "...",
  "highestKnownSafeVersion": "1.1.0",
  "metadataVersion": 4,
  "permissions": {},
  "reviewTier": "community",
  "source": {},
  "installedAt": "...",
  "lastVerifiedAt": "...",
  "revocationState": "clear"
}
```

这个状态用于权限 diff、签名复核、防回退、撤销处置和原子回滚。

## 18. 迁移映射

现有字段：

```text
marketplace_plugins.plugin_id       → plugin_id
marketplace_plugins.publisher_user_id → publisher_user_id
marketplace_plugins.latest_version  → latest_version
plugin_releases.package_key         → legacy_package_key / deployment root
plugin_releases.package_sha256      → package_sha256
plugin_releases.package_size        → package_size
plugin_releases.tuf_target_path     → 保留并升级为未来 targets path
```

迁移脚本必须：

- 为旧插件生成内部 UUID；
- 标记旧 release 为 `legacy` 或等价兼容状态；
- 不伪造签名或 provenance；
- 允许旧客户端继续读取；
- 新客户端对 legacy release 显示较低信任并阻止其冒充 v2 签名版本。
