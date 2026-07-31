# 技术设计：大乘小程序混合市场与可信发布

## 1. 当前实现基线

当前代码已经形成一个可迁移的 v1 纵向切片：

- `fabushi/web/src/handlers/marketplace.js` 负责认证发布者、检查插件 ID 所有权、阻止重复版本、拉取独立部署的安装包并校验大小和 SHA-256；
- 动态市场将部署根 URL 存入 `plugin_releases.package_key`，浏览接口返回固定的 `/mahayana/plugin.tar.gz`；
- 下载接口通过 307 跳转到插件部署；
- `marketplace_plugins` 和 `plugin_releases` 已经区分插件身份与版本；
- 官方市场仍使用 `.agents/plugins/marketplace.json` 和公共 `.well-known/mahayana/marketplace.json`；
- Flutter/CLI 已有官方和本地插件发现能力。

需要保留这些基础并升级，而不是另建不兼容系统。

## 2. 目标架构

```text
                         大乘市场控制平面
┌────────────────────────────────────────────────────────────┐
│ Identity / Namespace / Plugin / Release / Review / Trust   │
│ OIDC exchange / Signing / Provenance / Revocation / Audit  │
│ Search / Classification / Permission diff / Rollback       │
└───────────────────────────┬────────────────────────────────┘
                            │ 签名版本元数据
                            ▼
┌────────────────────────────────────────────────────────────┐
│ 每个插件一个独立 Cloudflare 逻辑服务                         │
│                                                            │
│ stable homepage / optional remote MCP / immutable releases │
│ static assets / version deployments / production alias     │
└───────────────────────────┬────────────────────────────────┘
                            │ CLI 直接下载
                            ▼
┌────────────────────────────────────────────────────────────┐
│ 大乘 CLI                                                   │
│ signature → expiry → revocation → domain → size → sha256  │
│ provenance → permission → anti-rollback → safe install    │
└────────────────────────────────────────────────────────────┘
```

## 3. 组件边界

### 3.1 市场 API Worker

负责：

- 大乘账号认证；
- 发布者命名空间；
- 插件身份和所有权；
- 发布意图与 OIDC 凭证交换；
- 版本登记、审核、搜索和详情；
- 签名版本元数据；
- 撤销、封禁、回滚和审计；
- 返回插件直接下载 URL。

不得：

- 永久代理所有安装包字节；
- 运行第三方插件代码；
- 与第三方插件共享写 Secret 或数据库；
- 把安装包存入 R2。

### 3.2 发布编排器

负责托管模式：

- 验证 GitHub Actions OIDC claims；
- 交换插件、仓库和工作流限定的短期发布凭证；
- 创建或绑定一个稳定 Cloudflare 插件项目；
- 生成预览版本和生产部署；
- 运行构建、扫描和契约测试；
- 生成安装包、manifest、provenance 和签名输入；
- 将发布收据提交市场。

实现可以位于现有 Web Worker、GitHub Actions workflow 和发布脚本中，但边界必须清楚，长期 Cloudflare 管理凭证只能存在于受保护的平台部署环境，不能下发给普通发布者。

### 3.3 插件 Cloudflare 服务

每个插件拥有一个稳定项目/服务。服务至少暴露：

```text
/                                      稳定主页
/mcp                                   远程 MCP（可选）
/mahayana/latest/plugin.json           当前生产版本指针
/mahayana/releases/<version>/<sha>/plugin.json
/mahayana/releases/<version>/<sha>/plugin.tar.gz
/mahayana/releases/<version>/<sha>/provenance.json
```

安装包和静态资源由 Worker 静态资源、Pages 构建输出或等价的服务内资源直接提供，禁止使用 R2。

### 3.4 大乘 CLI

负责：

- 初始化插件项目；
- 本地契约检查和测试；
- 发起 stage/release；
- 市场浏览和详情；
- 获取签名版本元数据；
- 直连下载；
- 安全校验、解包、原子安装和沙箱运行；
- 升级、权限确认、回滚、卸载和审计查询。

## 4. 插件与部署身份

### 4.1 插件 ID

推荐格式：

```text
io.mahayana.<publisher-namespace>.<plugin-slug>
```

限制：

- 全局唯一；
- 规范化后不可变；
- 命名空间必须经过账号、GitHub 或域名验证；
- 插件项目、日志、审计和 Cloudflare 资源映射均使用内部不可变 UUID，外部使用稳定 plugin ID。

### 4.2 Cloudflare 项目映射

```text
plugin UUID → cloudflare account → project/service name → stable hostname
```

服务名可由平台生成，不能直接依赖用户输入：

```text
mahayana-<namespace-hash>-<plugin-slug>-<short-id>
```

一个插件只绑定一个主项目。版本通过 Cloudflare Worker version/deployment 或 Pages deployment 表示。Cloudflare Worker 的版本记录完整代码、静态资源、绑定和兼容设置；部署决定哪个版本对外服务，因此可以在同一稳定服务内实现不可变版本、生产提升和回滚。

## 5. 不可变发布布局

正式版本路径：

```text
/mahayana/releases/<semver>/<sha256>/plugin.tar.gz
/mahayana/releases/<semver>/<sha256>/plugin.json
/mahayana/releases/<semver>/<sha256>/provenance.json
```

约束：

- `<pluginId, version>` 只能登记一次；
- URL 中的 SHA 必须等于安装包实际 SHA-256；
- 正式版本响应必须带长期缓存和不可变语义；
- 内容、大小或 manifest 不一致时发布失败；
- `latest` 只返回指针元数据，不能覆盖正式版本内容；
- 发布者不能删除审计记录；撤销通过状态和撤销元数据实现；
- 老版本按保留期保存，至少覆盖回滚和已安装用户恢复窗口。

## 6. 发布模式

### 6.1 托管模式

```text
CLI login
  → create publish intent
  → GitHub Actions obtains OIDC token
  → marketplace exchanges short-lived publish token
  → build/test/scan
  → upload Cloudflare version without exposing platform token
  → smoke test immutable version URL
  → submit release metadata
  → market verifies and signs
  → pending review
  → approve and promote production deployment
```

发布凭证必须限制：

- publisher ID；
- plugin ID；
- repository；
- commit SHA；
- workflow 文件；
- GitHub environment；
- stage 或 release 权限；
- 很短的过期时间；
- 单次 nonce。

### 6.2 自托管模式

```text
publisher deploys own Cloudflare service
  → requests ownership challenge
  → serves challenge under approved path
  → submits immutable release metadata
  → market fetches manifest/package/provenance
  → verifies domain ownership, hash, size and policy
  → pending review
```

自托管不得绕过签名市场元数据、权限、审核和撤销机制。

## 7. 发布元数据

规范化 release 元数据至少包含：

```json
{
  "schemaVersion": 2,
  "protocol": "mahayana.plugin-release.v2",
  "pluginId": "io.mahayana.bhrum.hello",
  "version": "1.0.0",
  "deploymentMode": "managed",
  "releaseStatus": "approved",
  "reviewTier": "community",
  "homepageUrl": "https://example.workers.dev/",
  "runtimeUrl": "https://example.workers.dev/mcp",
  "package": {
    "url": "https://example.workers.dev/mahayana/releases/1.0.0/<sha>/plugin.tar.gz",
    "sha256": "<64 hex>",
    "size": 12345,
    "contentType": "application/gzip"
  },
  "manifestUrl": "https://example.workers.dev/mahayana/releases/1.0.0/<sha>/plugin.json",
  "provenanceUrl": "https://example.workers.dev/mahayana/releases/1.0.0/<sha>/provenance.json",
  "permissions": {
    "network": ["api.example.com"],
    "filesystem": ["workspace:read"],
    "secrets": [],
    "commands": false
  },
  "source": {
    "repository": "https://github.com/example/hello",
    "commitSha": "<sha>",
    "workflow": ".github/workflows/mahayana-plugin-release.yml",
    "runId": "123456"
  },
  "publishedAt": "2026-07-31T00:00:00Z",
  "expiresAt": "2026-08-07T00:00:00Z",
  "metadataVersion": 1,
  "signatures": [
    {"keyId": "marketplace-2026-01", "algorithm": "ed25519", "signature": "..."}
  ]
}
```

签名覆盖规范化的 `signed` 部分，不得覆盖动态下载统计等非安全字段。

## 8. 签名和信任

### 8.1 市场签名

- CLI 内置或安全更新市场根公钥；
- 在线目标签名密钥可轮换；
- 版本元数据必须有市场签名；
- 根密钥与在线签名密钥分离；
- 密钥 ID、算法、有效期和轮换记录可审计。

### 8.2 发布者证明

托管模式以 OIDC claims、源码仓库和 workflow 绑定为发布者证明；自托管模式还需要域名/部署所有权证明。可在兼容结构中增加发布者签名，但不得把长期私钥直接保存在普通仓库 Secret 中作为唯一信任来源。

### 8.3 TUF 思想

本轮不要求完整实现 TUF 所有角色，但必须实现：

- 受信任根公钥；
- 目标文件哈希和大小；
- 签名元数据版本；
- 过期时间；
- 防版本回退；
- 防旧元数据冻结；
- 防元数据混搭；
- 密钥轮换和撤销；
- 未来可升级到 root/targets/snapshot/timestamp 结构的数据格式。

## 9. 权限模型

插件 manifest 和市场元数据都必须声明相同权限：

```json
{
  "network": ["api.example.com"],
  "filesystem": ["workspace:read"],
  "secrets": [],
  "commands": false,
  "mcpTools": ["search"],
  "uiSurfaces": ["chatPanel"]
}
```

规则：

- 默认拒绝未声明能力；
- 下载后的 manifest 权限必须与签名元数据一致；
- 升级权限扩大必须重新确认；
- 市场审核可拒绝过宽权限；
- `official` 不代表无限权限；
- CLI 和图形界面使用相同权限语义。

## 10. 下载和安装事务

```text
1. 获取市场签名元数据
2. 验证根信任、签名、metadataVersion 和 expiresAt
3. 检查 blocked/revoked/deprecated 状态
4. 检查 anti-rollback 本地最高已知版本
5. 验证 URL 为批准 Cloudflare HTTPS 域名和不可变路径
6. 限制 Content-Length 和流式最大字节数
7. 下载到隔离临时目录
8. 验证大小、SHA-256 和内容类型
9. 安全解包，拒绝绝对路径、路径穿越、链接逃逸和文件数量炸弹
10. 验证内部 manifest、pluginId、version、permissions
11. 展示权限差异并获取必要确认
12. 原子移动到版本化插件目录
13. 更新当前版本指针
14. 启动并进行健康检查
15. 失败时回滚指针并保留诊断
```

建议安装布局：

```text
<plugin-store>/<pluginId>/
├── versions/1.0.0/<sha>/
├── versions/1.1.0/<sha>/
├── current -> versions/1.1.0/<sha>
└── install-state.json
```

## 11. 回滚、撤销和封禁

- 回滚：生产部署重新指向已批准旧版本；不改变旧版本内容；
- 撤销：某版本不可新安装/升级，已安装用户收到风险状态；
- blocked：插件整体禁止新安装和更新；
- deprecated：仍可使用但提示迁移；
- CLI 默认拒绝回退到低于本地最高已知安全版本，只有明确回滚元数据和用户确认时允许；
- 撤销和审核状态必须在签名元数据中体现。

## 12. 审核流水线

自动检查至少包括：

- manifest schema；
- 包大小、文件数量、压缩炸弹和路径安全；
- 依赖和恶意文件扫描；
- Secret 扫描；
- 权限合理性；
- 域名和重定向策略；
- 主页和 MCP 健康检查；
- 安装、启动、卸载和重装；
- provenance 与 commit/workflow 关联；
- 不可变 URL 再次获取一致性。

人工审核重点：

- 名称和描述是否误导；
- 权限是否与功能匹配；
- 数据处理和隐私；
- 高风险命令、网络或 Secret 使用；
- verified/official 等级授予。

## 13. 兼容与演进

- 保留 v1 浏览、发布和 307 下载路径；
- v1 固定包路径只能迁移成 legacy release，不能成为新正式版本；
- 新增 v2 API 和签名元数据，不破坏旧字段；
- 官方 GitHub Release 构件继续可用，同时逐步加入 v2 元数据；
- Flutter registry 服务先支持新字段，再切换默认信任判定；
- 数据库采用追加字段/新表迁移，禁止破坏已发布版本记录；
- 迁移期允许市场同时返回 legacy 和 v2 release，但新 CLI 必须优先 v2。

## 14. 可观测性

每次关键动作写入不可变审计事件：

- publisher authenticated；
- namespace claimed；
- publish intent issued；
- OIDC exchanged；
- build and scan completed；
- Cloudflare version created/promoted/rolled back；
- release submitted/approved/rejected/revoked；
- signature created/rotated；
- CLI install/upgrade/rollback failed or succeeded。

审计事件不得包含 Secret、Token 或完整用户私密数据。
