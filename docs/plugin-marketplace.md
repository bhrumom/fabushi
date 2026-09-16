# 大乘 CLI 插件市场

## 当前任务追加目标

本规范是任务 `mahayana-marketplace-cloudflare-20260730` 的目标架构与验收依据。后续开发、修复、GitHub Actions 验证和 PR 验收不得只满足示例插件能够偶然安装运行，还必须满足本文定义的发布、发现、可信分发、隔离部署和安全安装模型。

### CWA-009 当前发布边界

Fabushi 当前明确采用“GitHub 托管、私有服务器审核”的发布链路：源码、不可变 GitHub
Release 和安装包继续放在 GitHub；自有安全服务器轮询市场队列，下载并校验 GitHub 包，
执行 ClamAV、密钥、依赖/SBOM、隔离动态探针和 Cosign 签名验签。Worker/D1 只保存来源、
摘要、大小、签名和审核状态；全部通过后才原子公开，复扫失败自动撤销。GitHub Actions
不执行这套插件审核或发布。CWA-009 的边界优先于本文早期“Cloudflare 独立插件站点负责
安装包”的历史描述。

## 设计原则

大乘市场采用“中央控制平面 + 插件独立分发与运行平面”的混合架构：

- 市场中心负责账号、命名空间、审核、搜索、版本索引、权限声明、签名、撤销和安全治理。
- 每个插件是独立的逻辑部署单元；它的网页/MCP Runtime 可以部署到独立的 Cloudflare Pages 项目或 Cloudflare Worker 服务，但源码、不可变 Release 和安装包归 GitHub 托管。
- 一个插件不等于一台独立服务器，但必须具有独立身份、部署边界、权限边界、Secret、版本和回滚生命周期。
- 每个版本必须是不可变发布物；同一插件 ID 与版本不得被新内容覆盖。
- 插件网页、远程 MCP Runtime 和运行时静态资源由插件自己的站点提供；源码、GitHub Release 和安装包不迁入 Cloudflare。
- 禁止把插件包或插件静态资源放入 R2；市场数据库只保存目录和可信元数据。
- 正常下载路径由 CLI 按市场签名元数据直接访问 GitHub 不可变 Release 资产。自有安全服务器在审核时拉取并验证发布物；市场 Worker 不成为日常安装包流量的永久代理。

## 发布者模型

### 默认托管模式

普通发布者只需要完成：

```bash
mahayana login
mahayana plugin publish <plugin-directory>
```

发布者先把源码和不可变安装包上传到 GitHub Release，再登记市场版本。平台登记候选版本并将其置为 `pending/unlisted`；自有安全服务器完成扫描、签名和回调后才公开。若插件需要网页或 MCP Runtime，平台仍可负责创建或绑定独立 Cloudflare 项目；普通用户不需要直接管理 Wrangler、Cloudflare API Token、Worker 名称或上传路径。

### 高级自托管模式

企业或高级开发者可以使用自己的 Cloudflare 账户和项目，但必须：

- 证明部署地址所有权；
- 使用 HTTPS 的 `workers.dev`、`pages.dev` 或经市场批准的自定义域名；
- 提供指向 GitHub 不可变 Release 资产的版本清单和安装包；
- 接受市场服务对清单、包内容、哈希、大小、签名和运行端点的重新验证。

## 插件身份和部署隔离

每个插件必须拥有稳定且全局唯一的发布者命名空间与插件 ID，例如：

```text
io.mahayana.<publisher>.<plugin>
```

每个插件必须能够独立执行以下操作，而不会影响其他插件：

- 发布和回滚；
- 下架和撤销；
- 配置 Secret 与权限；
- 查看日志和配额；
- 删除运行时；
- 冻结某个有安全问题的版本。

除非平台提供经过明确隔离的共享服务，否则不同插件不得共享写权限、部署凭证、Secret、Durable Object、KV 命名空间或数据库。

## 不可变发布物

推荐的插件站点结构为：

```text
/
/mcp
/mahayana/releases/<version>/<sha256>/plugin.json
/mahayana/releases/<version>/<sha256>/plugin.tar.gz
/mahayana/latest/plugin.json
```

其中：

- `releases/<version>/<sha256>` 下的文件不可覆盖；
- `latest/plugin.json` 只能作为可更新指针，不能成为唯一可信发布物；
- `plugin.json` 必须包含插件 ID、版本、安装包 URL、SHA-256、大小、运行时类型、权限、发布时间和来源证明引用；
- 同一个插件 ID、版本和内容哈希组合只能登记一次；
- 旧版本应按保留策略继续可用，以支持回滚和可复现安装。

兼容迁移期间可以读取旧路径 `/mahayana/plugin.json` 和 `/mahayana/plugin.tar.gz`，但新发布必须优先生成并登记不可变版本 URL。

## 发现和浏览

公共市场目录由 Platform Worker 和 D1 提供。D1 只保存元数据，不保存安装包字节。

CLI 通过市场 API 浏览和搜索：

```text
GET /v1/marketplace/plugins
GET /v1/marketplace/plugins?q=<query>&platform=<platform>
GET /v1/marketplace/plugins/<plugin-id>/releases/<version>
```

公开列表只返回满足以下条件的版本：

- 可见性允许公开；
- 审核状态为 approved；
- 发布者和插件未被封禁；
- 发布物没有进入撤销列表；
- 支持当前请求平台；
- 存在有效的不可变 GitHub 下载 URL、SHA-256 和大小。

内置 `.agents/plugins/marketplace.json` 是当前仓库的本地安装与发现索引，不是云端市场数据库。

## 下载模型

推荐的正常路径为：

```text
CLI -> 大乘市场 API 获取签名元数据
CLI -> GitHub 不可变 Release 资产直接下载
CLI -> 本地验证后安装
```

市场版本响应至少包含：

```json
{
  "pluginId": "io.mahayana.publisher.plugin",
  "version": "1.0.0",
  "downloadUrl": "https://plugin.example/mahayana/releases/1.0.0/<sha256>/plugin.tar.gz",
  "packageSha256": "<64 hex characters>",
  "packageSize": 12345,
  "publisher": "publisher-id",
  "signature": "<marketplace signature>",
  "provenance": "<build provenance reference>",
  "publishedAt": 0,
  "expiresAt": 0
}
```

CLI 必须验证：

1. URL 使用 HTTPS，且域名和端口符合市场策略；
2. URL 与市场批准的插件部署身份一致；
3. 实际字节数与 `packageSize` 一致；
4. 实际 SHA-256 与 `packageSha256` 一致；
5. 市场元数据签名有效且未过期；
6. 发布物未撤销；
7. 不允许无提示版本回退；
8. 插件包内的插件 ID 和版本与市场元数据一致。

市场 Worker 可以在发布阶段下载插件包进行三方比对，也可以提供显式的诊断或受控兼容端点，但默认安装流程不得依赖市场 Worker 代理所有包字节。

## 安装和运行安全

安装流程必须：

1. 下载到随机 staging 目录；
2. 限制压缩包和解压后大小；
3. 拒绝绝对路径、父目录穿越、符号链接逃逸和特殊设备文件；
4. 校验 `.codex-plugin/plugin.json`、`.mahayana/plugin.json` 与 `.mcp.json`；
5. 校验插件 ID、版本、平台和权限声明；
6. 安装成功后原子重命名到最终目录；
7. 失败时清理 staging 和不完整目录；
8. 默认拒绝覆盖已有插件或已有版本；
9. 权限扩大时要求用户重新确认；
10. 更新本地 `.agents/plugins/marketplace.json`。

插件可以提供本地 stdio MCP Runtime、远程 HTTPS MCP Runtime 或两者兼有。CLI 必须根据平台、权限和用户选择使用明确的 runtime variant，不能静默切换到权限更高的运行时。

## 发布认证和供应链证明

可信发布由自有安全服务器完成：服务器使用受限 token 读取/回写审核队列，用本机保管的
Cosign 私钥签名，Worker 固定服务名、key ID 和公钥文件 SHA-256。市场发布 Token、私钥和
扫描器凭据不得进入 GitHub Actions、插件包或扫描容器。

市场版本应记录：

- 源代码仓库；
- commit SHA；
- 安全服务器实例和服务源码 SHA；
- 构建者身份；
- 安装包 SHA-256 和大小；
- Cloudflare 部署标识；
- 签名和来源证明；
- 审核结果与撤销状态。

本轮不运行脚本/插件 E2E；用户明确取消该类 E2E，产品 post-main E2E 门保持未完成。

## 审核状态

建议的市场状态包括：

- `private`
- `unlisted`
- `community`
- `verified`
- `official`
- `blocked`

普通用户首次发布默认进入 `unlisted + pending`。自动扫描通过后可以进入社区可见状态；身份、安全和人工审核通过后可以提升为 verified；官方维护的小程序标记为 official。

## 历史 GitHub Actions 最终验收说明

以下是早期 Cloudflare 插件站点任务的历史验收清单，不是 CWA-009 的安全审核执行平面。
CWA-009 不启动该 E2E 清单，并以自有安全服务器的非 E2E 安全结果作为本轮实现证据：

1. 登录大乘 CLI；
2. 构建并测试真实示例小程序；
3. 发布到独立 Cloudflare Pages/Worker 服务；
4. 验证网页、MCP Runtime、不可变 `plugin.json` 和不可变 `plugin.tar.gz`；
5. 发布服务重新下载并验证部署站点上的包；
6. 市场登记插件、版本、平台、哈希、大小、下载 URL 和审核状态；
7. CLI 浏览和搜索能够发现已批准版本；
8. CLI 从插件 Cloudflare 站点直接下载，而不是依赖 R2 或默认市场代理；
9. CLI 校验 URL、哈希、大小、签名/可信元数据和包内身份；
10. CLI 安全解包并原子安装；
11. CLI 发现并运行已安装小程序命令；
12. Actions 上传发布、浏览、下载、校验、安装和运行证据构件；
13. 失败日志能够区分构建失败、部署失败、市场登记失败、下载失败、校验失败、安装失败和运行失败；
14. 重复发布同一版本但内容不同必须失败；
15. 被撤销、未批准或权限不匹配的版本不能被公开安装。

现有 `cloud-market-hello` 是历史端到端验收样例；本轮按用户要求不执行它。架构和命令
不能只为该固定插件硬编码，必须对普通发布者的小程序通用。

## 完成定义

只有同时满足以下条件，才能认为大乘 CLI 云端插件市场任务完成：

- 普通发布者可以通过统一 CLI 发布流程创建独立逻辑部署；
- 市场中心只保存治理和可信元数据；
- 插件包和静态资源全部来自插件自己的 Cloudflare 站点，且不使用 R2；
- 每个版本具有不可变 URL 和不可变内容；
- CLI 默认直连下载并完成本地可信校验；
- 安装过程具备路径、大小、身份、版本和权限安全检查；
- 发布者身份、构建来源和撤销状态可审计；
- 自有安全服务器对真实 GitHub 包给出可复核的四项扫描、签名验签、promotion/revoke 和
  Worker 审计结果；本轮不执行脚本/插件 E2E，故产品 E2E 完成门保持待授权状态。
