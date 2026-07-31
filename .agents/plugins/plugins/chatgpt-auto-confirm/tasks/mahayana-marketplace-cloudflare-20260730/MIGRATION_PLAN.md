# 迁移计划：从市场 v1 到混合可信市场 v2

## 1. 迁移原则

- 不推倒现有官方市场和动态发布接口；
- 新能力以追加字段、新表和新 API 落地；
- 先让客户端理解 v2，再切换发布默认；
- legacy 版本不能伪装成已签名 v2 版本；
- 任一阶段都能回退到上一稳定版本；
- 数据库迁移、客户端兼容和 Cloudflare 发布必须分别可验证。

## 2. 当前状态

### 官方市场

- `.agents/plugins/marketplace.json` 为内置清单；
- 公共 `.well-known/mahayana/marketplace.json` 为发现入口；
- 平台构件目前主要从 GitHub Releases 下载；
- 安装脚本验证 `.sha256` 并检查插件契约。

### 动态市场

- 发布者提交 plugin ID、version、deployment URL、SHA、大小和平台；
- 市场从 `<deploymentUrl>/mahayana/plugin.tar.gz` 读取并校验；
- `pluginId + version` 已禁止重复；
- 普通发布者 pending，管理员可 approved；
- 浏览返回直接部署 URL；
- 下载端点 307 跳转。

这是一条有价值的 v1 纵向链路，迁移应复用认证、审核、数据库和直连下载方向。

## 3. 阶段 0：契约和测试保护

在修改生产逻辑前：

- 固化现有 v1 浏览、发布、审核和 307 行为测试；
- 为官方清单、安装脚本和 Flutter registry 增加兼容快照；
- 建立数据库迁移测试夹具；
- 建立真实 Cloudflare 测试插件和专用测试命名空间；
- 确认所有生产 Secret 只在 GitHub environment/Cloudflare 平台中使用。

退出条件：现有行为有自动回归保护。

## 4. 阶段 1：数据模型扩展

新增或扩展：

- publisher namespaces；
- internal plugin UUID；
- deployment mode 和 Cloudflare project mapping；
- immutable package URL；
- permissions、provenance、metadataVersion 和 expiresAt；
- signature、review、revocation、production history 和 audit 表。

旧记录迁移：

- 保留 `package_key`；
- 标记为 legacy release；
- 为插件生成 UUID；
- 不生成伪造 provenance 或签名；
- review state 和 latest version 保持原值。

退出条件：旧数据和新数据均可读取，迁移幂等。

## 5. 阶段 2：v2 只读市场

实现：

- v2 browse/detail/release metadata；
- 规范化 release JSON；
- 市场签名和根公钥；
- review tier、permissions、source、revocation 字段；
- legacy release 明确标识；
- v1 API 保持不变。

客户端先支持：

- 解析 v2；
- 验证签名；
- 显示 legacy/v2 信任差异；
- 遇到未知附加字段不崩溃。

退出条件：新客户端可浏览 v2，旧客户端仍可浏览 v1。

## 6. 阶段 3：不可变自托管发布

先升级现有动态发布链路：

- 新版本必须使用 version+SHA 不可变路径；
- 验证 Cloudflare hostname 和所有权；
- 验证 manifest、permissions、provenance；
- 市场签名元数据；
- 支持 revoke/blocked；
- 固定 `/mahayana/plugin.tar.gz` 只允许 legacy 兼容，不能创建新正式 release。

这样可以在平台托管发布完成前验证完整的 v2 下载、安装和信任链。

退出条件：真实自托管示例插件完成两版本发布、安装、升级、回滚和撤销。

## 7. 阶段 4：OIDC 托管发布

实现：

- publish intent；
- GitHub Actions OIDC claims 验证；
- 短期、单插件、单版本、单阶段发布 token；
- nonce 防重放；
- 平台创建/绑定每插件独立 Cloudflare 项目；
- Worker version/Pages deployment；
- stage、审核、production promotion；
- provenance 和 release receipt。

退出条件：普通测试发布者不配置 Cloudflare Token 即可完成发布。

## 8. 阶段 5：CLI 安全安装

升级 CLI：

- 获取签名 v2 元数据；
- 验证签名、过期、撤销和 anti-rollback；
- 验证 Cloudflare 域名和不可变路径；
- 流式大小限制和 SHA；
- provenance 和权限一致性；
- 安全解包和原子安装；
- 权限扩大重新确认；
- 版本化安装目录和 current 指针；
- 回滚和审计。

退出条件：干净环境完成真实 E2E 和攻击测试。

## 9. 阶段 6：UI 与发布者控制台

- 市场信任等级和权限展示；
- 发布阶段和审核反馈；
- provenance、Actions run 和部署详情；
- 版本历史、production、rollback 和 revoke；
- 已安装插件的安全状态；
- CLI、Flutter 和 Web 状态语义一致。

退出条件：关键状态和错误可被普通用户理解。

## 10. 阶段 7：默认切换和旧接口退役策略

切换条件：

- v2 发布和安装稳定；
- 官方插件也有 v2 元数据或明确兼容状态；
- 旧客户端占比和错误率可接受；
- rollback 演练成功；
- 安全运营具备撤销能力。

切换步骤：

1. 新 CLI 默认请求 v2；
2. 新发布默认托管模式；
3. v1 发布接口返回 deprecation 警告；
4. 固定包路径不再接受新正式版本；
5. v1 浏览继续只读一段兼容期；
6. 根据遥测和版本支持策略决定退役时间。

## 11. 数据和 API 回滚

- 数据库迁移必须可向前修复，避免删除列；
- 新表失败时 v1 查询仍可用；
- v2 发布失败不更新 production；
- 客户端可以在服务器 v2 暂时不可用时读取缓存的最后可信元数据，但必须检查过期时间；
- 市场签名故障时停止新安装，不得降级成无签名信任；
- Cloudflare promotion 失败时保持原 production deployment。

## 12. 真实验收插件

建立专用测试插件：

```text
io.mahayana.test.hello
```

版本：

- `1.0.0`：基础主页、MCP 健康检查、最小权限；
- `1.1.0`：功能升级并增加一个可控权限，用于权限 diff。

此插件用于贯穿所有阶段，不得使用只存在本地的 mock 替代。

## 13. 迁移完成定义

- 新普通发布者默认走托管 OIDC；
- 新正式版本全部不可变且有市场签名和 provenance；
- CLI 默认直连插件服务并执行完整校验；
- v1 旧客户端仍在承诺窗口内可用；
- R2 未被用于插件包或静态资源；
- 市场没有成为下载字节瓶颈；
- 回滚、撤销和密钥轮换完成演练；
- 所有验收证据来自 GitHub Actions 和真实 Cloudflare 服务。
