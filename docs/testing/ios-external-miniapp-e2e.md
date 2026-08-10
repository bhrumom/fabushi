# iOS 外部小程序全自动化测试架构

状态：**规范性文档（Normative）**
目标插件：`global-dharma`（界面名：全球法布施）

## 结论

移动端插件安装只有一条允许的生产路径：

`Flutter UI -> MahayanaMarketplaceService -> mahayana_product_execute -> MahayanaProductClient -> shared marketplace installer -> codexHome/plugins/<pluginId>`

自动化测试必须从用户界面触发这条路径。测试脚本、GitHub Actions、宿主机 CLI 都不得把插件目录预先复制到 Simulator 的 App sandbox，也不得通过制造 `localPluginPath` 来伪造“已安装”。

## 为什么旧方案被禁止

旧的第一版 iOS workflow 在宿主机执行 `mahayana marketplace install --repository ...`，随后把结果 `cp -R` 到 Simulator 的 `codex/plugins`。这种方法只能证明 App 能发现被外部塞进去的文件，不能证明 iOS App 的真实搜索、下载、哈希校验、manifest 校验、原子安装和运行时重载链路正常。因此该路径属于假阳性风险，永久禁止作为移动端安装验收方式。

`fabushi/tool/ios_e2e/verify_architecture.py` 会在 CI 中硬性阻止该方案回归。

## 生产安装不变量

1. Marketplace 查找使用精确 `pluginId`；UI 文案只用于用户搜索，不作为安装身份。
2. 服务端 release metadata 必须与请求的 `pluginId`、`version` 一致。
3. 下载包必须同时匹配 `packageSize` 与 `packageSha256`。
4. 解包后 `.codex-plugin/plugin.json` 的 `name`、`version` 必须再次与 release identity 一致。
5. 安装先进入同目录 staging，完成校验和 receipt 写入后使用原子 rename 变为可见状态。
6. receipt 协议为 `mahayana.marketplace.install-receipt.v1`，至少记录 `pluginId`、`version`、`packageSha256`、`packageSize`、`source`。
7. 已存在插件只有在 receipt 的 `pluginId/version/SHA-256` 完全相同时才允许幂等成功；不同 release 必须走显式更新流程。
8. Flutter 成功安装后关闭已有 embedded Runtime，下一次 Runtime 创建必须重新发现插件。

## 自动化分层

### L1 — 确定性合同测试（每个相关 PR）

Linux runner 执行：

- Rust 安装器/产品命令单元测试；
- Python flow 语法与 JSON schema 检查；
- 架构 guard，禁止假安装、模糊 locator、未固定的 Appium 版本；
- 这些测试不依赖 iOS Simulator、Marketplace 在线状态或测试账号。

L1 的目标是快速证明安装算法和测试架构没有被破坏。

### L2 — iOS Simulator 黑盒验收（内部 PR / 手动）

Appium + XCUITest 只从 accessibility identifier 操作 App，不使用坐标。流程必须是：

1. 擦除并启动干净 Simulator；
2. 安装 Fabushi App；
3. 仅注入固定测试账号的既有 CI 登录凭据，不预装任何插件；
4. 搜索“全球法布施”；
5. 断言 `global-dharma` 尚未安装；
6. 点击 App 内的“安装”；
7. 等待精确 `global-dharma.installed` 状态；
8. 进入该小程序聊天；
9. 点击“打开应用”；
10. 等到 MiniApp Host 的 WebView 完成加载并注入 MCP bridge；
11. 从 App sandbox 读取 production install receipt，只用于**验证证据**，不得用于准备状态；
12. 校验 receipt、manifest、版本、SHA-256、source 身份一致；
13. 每一步保存 PNG、accessibility XML、JSONL timeline；全程保存 Simulator 视频、Appium 日志和 iOS 日志。

### L3 — 真实 Marketplace Canary（定时 / 发布前）

同一个 L2 黑盒 workflow 定时运行，始终安装 Marketplace 当前审核通过的 `global-dharma` release。它用于发现 Marketplace、下载、账号、iOS Runtime 或远端发布变化造成的回归。

具备受控真实 iPhone runner 后，应再增加真机 canary；Simulator 不是权限、后台生命周期、系统资源约束的最终证明。真机层不得替代 L1/L2，而是低频补充。

## E2E Control v1

`fabushi.e2e.control.v1` 是用于快速编写确定性测试与状态诊断的受限控制协议。它不是网络端口：仅在 Debug 构建同时显式传入 `--dart-define=FABUSHI_E2E_CONTROL=true` 时，在 App 自己的 `mahayana-runtime/e2e-control` 目录消费原子 JSON request/response 文件。

当前允许的方法：

- `ping`
- `auth.status`
- `marketplace.search`
- `marketplace.install`
- `marketplace.inspect`
- `runtime.status`

这些方法只能调用现有生产服务，不允许客户端传入安装目录或任意 Rust command。L2 黑盒流程明确禁止通过 Control 调用 `marketplace.install`；它必须点击 UI 的“安装”。Control 的安装方法保留给更低层、确定性的集成测试复用生产 Installer。

宿主机客户端为 `fabushi/tool/ios_e2e/control_client.py`。协议响应可以作为 CI artifact 保存，但不得返回测试账号 token。

## Locator 合同

自动化只能依赖稳定的语义 ID：

- `e2e.chat.search`
- `e2e.miniapp.result.<pluginId>.registry`
- `e2e.miniapp.install.<pluginId>`
- `e2e.miniapp.result.<pluginId>.installed`
- `e2e.miniapp.chat.<pluginId>.installed`
- `e2e.miniapp.open.<pluginId>`
- `e2e.miniapp.host.<pluginId>.loading|ready|error`

目标插件的断言必须使用完整 `global-dharma` ID。禁止 `BEGINSWITH ... installed`、`ENDSWITH .installed` 等会匹配其他插件的模糊断言。

## 凭据与诊断

- 测试账号 token 只来自 GitHub Secret；不得写入仓库、Appium capabilities、截图 metadata 或 timeline。
- CI 可以使用现有测试账号 marker 机制建立固定测试会话；这是认证 fixture，不是插件安装 shortcut。
- 失败时始终上传截图、页面树、timeline、视频、Appium/iOS/Flutter build 日志。
- 生产安装成功后上传的 receipt 是可审计证据；日志中不得出现 token。

## 自动修复边界

测试 workflow 只负责产生确定性的失败与诊断证据，不持有修改仓库所需的写权限。若接入 coding agent，必须是独立受限流程：读取失败 artifact -> 修改当前 PR branch -> 重新触发完整 CI。禁止测试 job 自己无限循环修改代码。
