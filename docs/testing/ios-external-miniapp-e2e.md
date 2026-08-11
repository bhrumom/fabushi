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
- Python flow、Control client 与 Marketplace fixture 语法检查；
- 从仓库 canonical `.agents/plugins/plugins/global-dharma` 构建确定性 tar.gz，重算 SHA-256/size，并验证 `pluginId=global-dharma`、当前 canonical version 与 `mobile` runtime 合同；
- 架构 guard，禁止假安装、模糊 locator、未固定的 Appium/XCUITest/Xcode 版本，并强制 L2/L3 分层；
- 这些测试不依赖 iOS Simulator、Marketplace 在线状态或测试账号。

L1 的目标是快速证明安装算法和测试架构没有被破坏。

### L2 — iOS Simulator 确定性黑盒验收（内部 PR / 默认手动）

Appium + XCUITest 只从 accessibility identifier 操作 App，不使用坐标。L2 固定使用 `macos-15` runner，并通过 `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer` 明确锁定 Xcode 16.4；不得依赖 GitHub runner 的默认 Xcode。Appium 固定为 `3.6.0`，XCUITest Driver 固定为 `12.3.1`。

L2 使用 `marketplace_mode=fixture`。fixture 绑定 `127.0.0.1` 的 OS 分配临时端口（`port=0`），健康检查显式绕过环境 HTTP 代理；实际 `baseUrl` 只有在 fixture ready 后才注入 App。fixture **只替换 Marketplace 目录/Release/Download 的网络分发层**：

- 包内容必须从当前 commit 的 canonical `.agents/plugins/plugins/global-dharma` 生成，不允许维护第二份“测试插件”；
- tar.gz 必须确定性生成，并把 `pluginId/version/packageSha256/packageSize/source` 作为 fixture release identity；
- fixture 只能提供 `/v1/marketplace/plugins`、release metadata 与 download bytes；禁止知道 `codexHome`、App sandbox、Simulator 路径，禁止安装或复制插件；
- App 通过 `MAHAYANA_API_BASE_URL` 指向 fixture，但搜索、下载、SHA/size/manifest 校验、receipt、原子安装仍全部由 production `MahayanaProductClient` 和共享 Rust Installer 完成；
- canonical 插件里的远程 `global-dharma` MCP endpoint 仍是真实 HTTPS 服务，因此“打开应用 -> WebView/MCP bridge ready”不会被 fixture 伪造。

内部 PR 必须强制使用 fixture；手动运行默认 fixture。这样代码 PR 的合并门不会因为线上 Marketplace 临时无 release、审核窗口或目录数据变化而抖动，同时又没有绕过任何 App 安装逻辑。

流程必须是：

1. 从当前 Xcode runtime 创建本次 run 专属的临时 iPhone Simulator，boot 必须有硬超时，并在证据采集后删除；
2. 安装 Fabushi App；
3. 仅注入固定测试账号的既有 CI 登录凭据，不预装任何插件；
4. 启动对应 Marketplace 模式，并通过 production `marketplace.search` 精确预检 `global-dharma` release；
5. 搜索“全球法布施”；
6. 断言 `global-dharma` 尚未安装；
7. 点击 App 内的“安装”；
8. 等待精确 `global-dharma.installed` 状态；
9. 进入该小程序聊天；
10. 点击“打开应用”；
11. 等到 MiniApp Host 的 WebView 完成加载并注入 MCP bridge；
12. 从 App sandbox 读取 production install receipt，只用于**验证证据**，不得用于准备状态；
13. 校验 receipt、manifest、版本、SHA-256、source 身份一致；fixture 模式还必须与本次生成的 fixture metadata 完全一致；
14. 每一步保存 PNG、accessibility XML、JSONL timeline；全程保存 Simulator 视频、Appium、Marketplace fixture（若使用）、Flutter build 和 iOS 日志。

### L3 — 真实 Marketplace Canary（nightly / 手动 live / 发布前）

`schedule` 事件必须强制 `marketplace_mode=live`，API base 固定为 `https://api.ombhrum.com`；手动运行可以显式选择 `live`。L3 使用同一个测试账号、同一个 production ProductClient/Installer、同一个 Appium flow 和同一组精确 locator，不允许为线上 canary 维护另一套安装脚本。

L3 在 UI 流程前同样通过 production `marketplace.search` 精确预检 `global-dharma` 的 `mobile` release。若线上没有审核通过的精确 release，必须以 `LIVE_MARKETPLACE_RELEASE_MISSING` 明确失败并上传 preflight evidence；不得回退到 fixture、内置 registry、静态 marketplace 文件或手工复制包来“把测试变绿”。它用于发现真实 Marketplace 目录、Release 发布、下载、账号、iOS Runtime 或远端 MCP 发布变化造成的事故。

具备受控真实 iPhone runner 后，应再增加低频真机 canary；Simulator 不是权限、后台生命周期、系统资源约束的最终证明。真机层不得替代 L1/L2/L3，而是额外补充。

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

禁止另建返回伪造结果的 CLI/TestDriver（例如固定返回空日志、空 actions、假 `resetProfile` 成功）。测试控制面必须查询或调用真实生产服务；也禁止提供环境变量让 test driver 在 release 构建中重新启用。架构 guard 会检查这些回归。

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
