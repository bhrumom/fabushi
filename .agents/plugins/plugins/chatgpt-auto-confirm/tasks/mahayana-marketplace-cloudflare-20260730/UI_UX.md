# UI/UX：大乘小程序发布、市场与安装

## 1. 设计目标

普通用户应感受到的是“大乘帮我发布小程序”，而不是“我需要学习 Cloudflare”。默认流程只暴露插件名称、权限、源码和发布阶段；Cloudflare 项目、Worker 版本、路由、Token 和 D1 属于平台内部细节。

高级用户可以选择自托管，但该入口必须明确标记为高级模式，并提供所有权验证和安全要求说明。

## 2. CLI 信息架构

目标命令：

```bash
mahayana plugin init
mahayana plugin test
mahayana plugin publish --stage
mahayana plugin release
mahayana plugin status
mahayana plugin rollback <version>
mahayana plugin revoke <version>
mahayana plugin install <plugin-id>
mahayana plugin upgrade <plugin-id>
mahayana plugin audit <plugin-id>
```

### 2.1 `plugin init`

交互内容：

- 插件显示名称；
- 插件 slug；
- 自动生成完整 plugin ID；
- 插件类型：网页、远程 MCP、本地 Runtime 或混合；
- 初始权限；
- 支持平台；
- 默认选择托管模式。

必须在创建前展示：

```text
完整插件 ID：io.mahayana.bhrum.hello
发布后该 ID 不能被其他账号使用。
部署模式：大乘托管
```

### 2.2 `plugin test`

按阶段输出：

```text
✓ manifest schema
✓ permission manifest
✓ package boundaries
✓ UI entry
✓ MCP health
✓ local install
✓ local launch
```

失败必须指出具体文件、字段和修复方式，不能只返回 `invalid package`。

### 2.3 `plugin publish --stage`

显示阶段：

```text
1/7 验证大乘账号
2/7 验证 GitHub 仓库和工作流
3/7 交换短期 OIDC 发布凭证
4/7 构建和安全扫描
5/7 创建 Cloudflare 预览版本
6/7 生成哈希、签名和来源证明
7/7 创建待审核版本
```

完成后展示：

- 插件 ID；
- 版本；
- 预览 URL；
- 不可变安装包 URL；
- SHA-256；
- Actions run；
- review state；
- 下一步命令。

不得在输出中显示 Cloudflare API Token、市场发布 Token 或 Secret。

### 2.4 `plugin release`

发布前确认：

- 版本不可再次使用；
- 权限变化；
- 生产别名将指向哪个版本；
- 审核等级；
- 回滚目标；
- 公开可见性。

普通发布者发布后默认为 `unlisted + pending`，不能用“已公开”误导用户。

### 2.5 自托管模式

高级流程明确要求：

- Cloudflare HTTPS URL；
- 所有权 challenge；
- 不可变版本路径；
- 主页和 MCP 健康检查；
- 包哈希、大小和 provenance；
- 市场审核。

界面必须说明：自托管不会绕过市场签名、权限和撤销机制。

## 3. 市场浏览

每张插件卡至少显示：

- 名称和完整 plugin ID；
- 发布者；
- 最新版本；
- 平台；
- 信任等级标签；
- 权限风险摘要；
- 已安装/可升级/已撤销状态。

信任等级视觉语义：

- `official`：官方；
- `verified`：已验证；
- `community`：社区；
- `unlisted`：未公开列出；
- `blocked`：危险或已封禁，禁止安装。

颜色不能是唯一信息来源，必须同时显示文字和图标/状态说明。

## 4. 插件详情

必须展示：

- 插件 ID、发布者和命名空间验证状态；
- 版本和发布时间；
- 托管或自托管；
- 主页和远程 MCP 地址；
- 源码仓库、commit、workflow 和 Actions run；
- SHA-256、大小和签名状态；
- 权限清单；
- 审核等级、撤销和安全公告；
- 更新说明与历史版本；
- 当前生产版本和可回滚版本。

不得把可变 `latest` URL 伪装成正式版本包地址。

## 5. 安装确认

首次安装对话框：

```text
插件：io.mahayana.bhrum.hello 1.0.0
发布者：bhrum（已验证）
信任等级：community
来源：GitHub Actions #123456

权限：
- 网络：api.example.com
- 文件：工作区只读
- Secret：无
- 系统命令：不允许
```

用户确认后，阶段状态依次为：

```text
获取可信元数据
验证签名和撤销状态
下载安装包
校验大小与 SHA-256
验证来源证明
安全解包
安装并启动
```

下载成功不能直接显示“安装成功”；只有原子安装和启动健康检查完成后才能显示成功。

## 6. 升级与权限变化

### 6.1 权限不变

可提供一键升级，仍需显示版本、来源和签名状态。

### 6.2 权限扩大

必须阻止静默升级，并突出新增权限：

```text
新增权限：
+ 网络访问 files.example.com
+ 工作区写入
```

用户拒绝后保持旧版本可运行，不得留下半升级状态。

### 6.3 信任降低

当插件从 verified 降级、版本被撤销或来源变化时，必须显式警告并默认拒绝自动升级。

## 7. 回滚

回滚界面显示：

- 当前版本；
- 目标版本；
- 回滚原因；
- 权限差异；
- 目标版本是否仍获批准；
- 数据兼容风险；
- 回滚后生产别名变化。

回滚只是切换到已有不可变版本，不能重新上传或覆盖旧版本。

## 8. 撤销和封禁

已安装插件被撤销时：

- 市场和本地插件页显示醒目风险状态；
- 解释撤销范围和原因；
- 提供停用、卸载、升级到安全版本等建议；
- 禁止重新安装被撤销版本；
- `blocked` 插件默认停止新启动，除非产品明确允许隔离诊断模式。

## 9. 发布者控制台

每个插件页面展示：

- 稳定 plugin ID；
- Cloudflare 服务映射，但不暴露平台 Secret；
- 当前 production deployment；
- 所有不可变版本；
- stage、pending、approved、revoked 状态；
- 构建与扫描结果；
- provenance；
- 权限历史；
- 下载和安装统计；
- 审核反馈；
- 回滚和撤销操作；
- 审计时间线。

## 10. 错误文案

错误必须可操作。例如：

- `版本 1.0.0 已经发布，不能覆盖；请使用新版本号。`
- `安装包 URL 不是不可变版本路径。`
- `市场签名无效，已拒绝安装。`
- `下载内容 SHA-256 与签名元数据不一致。`
- `插件请求了未在市场元数据声明的权限。`
- `该版本已撤销，安全版本为 1.0.2。`
- `OIDC token 的仓库或 workflow 与插件发布配置不匹配。`

不得只显示网络错误代码或空白页面。

## 11. 一致性要求

CLI、桌面、移动端和 Web 必须共用：

- plugin ID；
- 版本和发布状态；
- 权限语义；
- 信任等级；
- 安装状态；
- 撤销和回滚状态；
- 错误代码和核心文案。
